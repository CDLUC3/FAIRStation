#!/usr/bin/env python3
"""Provision staging only, using an explicit local JSON configuration and AWS SSO."""

import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys

from pipeline import aws


ROOT = Path(__file__).resolve().parent


def outputs(name):
    try:
        response = aws("cloudformation", "describe-stacks", stack_name=name)
    except subprocess.CalledProcessError as error:
        if "ValidationError" in error.stderr and "does not exist" in error.stderr:
            return None
        raise
    return {item["OutputKey"]: item["OutputValue"] for item in response["Stacks"][0].get("Outputs", [])}


def deploy(name, template, parameters, service_role):
    command = [
        "aws", "cloudformation", "deploy", "--stack-name", name,
        "--template-file", str(ROOT / "templates" / template),
        "--capabilities", "CAPABILITY_IAM", "--no-fail-on-empty-changeset",
        "--tags", "Program=uc3", "Service=fairstation", "Environment=stg",
        "CodeRepo=https://github.com/CDLUC3/FAIRStation",
        "--parameter-overrides",
    ]
    command += [f"{key}={','.join(value) if isinstance(value, list) else value}" for key, value in parameters.items()]
    if service_role:
        command += ["--role-arn", service_role]
    subprocess.run(command, check=True)
    return outputs(name)


def provision_secret(kms_key):
    name = "/uc3/fairstation/stg/secret_key_base"
    try:
        parameter = aws("ssm", "get-parameter", name=name)["Parameter"]
    except subprocess.CalledProcessError as error:
        if "ParameterNotFound" not in error.stderr:
            raise
    else:
        if parameter["Type"] != "SecureString":
            raise RuntimeError(f"{name} already exists but is not a SecureString")
        print(f"Preserving existing {name}", flush=True)
        return
    request = {"Name": name, "Type": "SecureString", "Value": secrets.token_hex(64),
               "Description": "FAIR Station staging Rails session signing secret"}
    if kms_key:
        request["KeyId"] = kms_key
    # Neither the secret nor the input JSON is placed in argv, a file, or console logs.
    subprocess.run(
        ["aws", "ssm", "put-parameter", "--cli-input-json", "file:///dev/stdin", "--no-cli-pager"],
        input=json.dumps(request), text=True, check=True, stdout=subprocess.DEVNULL,
    )
    print(f"Created {name}", flush=True)


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: AWS_PROFILE=<SSO-profile> python3 infra/provision.py /secure/path/staging.json")
    config = json.loads(Path(sys.argv[1]).read_text())
    required = (
        "AccountId", "Region", "VpcId", "PublicSubnetIds", "TaskSubnetIds",
        "DatabaseSubnetIds", "Hostname", "ConnectionArn", "GitHubOidcProviderArn",
    )
    for key in required:
        if not config.get(key):
            raise RuntimeError(f"Missing required configuration: {key}")
    for key in ("PublicSubnetIds", "TaskSubnetIds", "DatabaseSubnetIds"):
        if not isinstance(config[key], list) or len(config[key]) < 2:
            raise RuntimeError(f"{key} must be a JSON list with at least two subnets")
    if not config.get("CertificateArn") and not config.get("HostedZoneId"):
        raise RuntimeError("Supply CertificateArn or HostedZoneId for the application HTTPS certificate")
    os.environ["AWS_DEFAULT_REGION"] = config["Region"]
    os.environ["AWS_REGION"] = config["Region"]
    account = aws("sts", "get-caller-identity")["Account"]
    if account != str(config["AccountId"]):
        raise RuntimeError(f"Authenticated account {account} differs from configured staging account")
    connection = config["ConnectionArn"].split(":")
    if len(connection) != 6 or connection[3:5] != [config["Region"], account]:
        raise RuntimeError("CodeConnections ARN must belong to the configured account and region")
    if not re.fullmatch(rf"arn:aws:iam::{account}:oidc-provider/token\.actions\.githubusercontent\.com", config["GitHubOidcProviderArn"]):
        raise RuntimeError("Use the existing GitHub OIDC provider in this account")
    connection_details = aws("codeconnections", "get-connection",
                             connection_arn=config["ConnectionArn"])["Connection"]
    if connection_details["ConnectionStatus"] != "AVAILABLE" or connection_details["ProviderType"] != "GitHub":
        raise RuntimeError("CodeConnections must be an AVAILABLE GitHub connection before provisioning")
    service_role = config.get("CloudFormationServiceRoleArn", "")
    kms_key = config.get("SecretKeyKmsKeyArn", "")
    provision_secret(kms_key)
    database = deploy("fairstation-stg-database", "database.yaml", {
        "VpcId": config["VpcId"], "DatabaseSubnetIds": config["DatabaseSubnetIds"],
        "DatabaseInstanceClass": config.get("DatabaseInstanceClass", "db.t4g.micro"),
        "DatabaseEngineVersion": config.get("DatabaseEngineVersion", "8.4.11"),
        "MultiAZ": str(config.get("MultiAZ", False)).lower(),
    }, service_role)
    subprocess.run([
        "aws", "cloudformation", "update-termination-protection", "--stack-name", "fairstation-stg-database",
        "--enable-termination-protection", "--no-cli-pager",
    ], check=True)
    image = ""
    desired = 0
    previous = outputs("fairstation-stg-runtime")
    if previous:
        response = aws("ecs", "describe-services", cluster=previous["ClusterName"], services=[previous["ServiceName"]])
        if response.get("failures") or len(response.get("services", [])) != 1:
            raise RuntimeError("Cannot preserve the existing runtime; inspect ECS before updating infrastructure")
        service = response["services"][0]
        if len(service.get("deployments", [])) != 1 or service["pendingCount"]:
            raise RuntimeError("Wait for the active ECS deployment to finish before updating infrastructure")
        definition = aws("ecs", "describe-task-definition", task_definition=service["taskDefinition"])["taskDefinition"]
        image = definition["containerDefinitions"][0]["image"]
        desired = service["desiredCount"]
    runtime = deploy("fairstation-stg-runtime", "runtime.yaml", {
        "VpcId": config["VpcId"], "PublicSubnetIds": config["PublicSubnetIds"],
        "TaskSubnetIds": config["TaskSubnetIds"], "TaskSecurityGroupId": database["TaskSecurityGroupId"],
        "DatabaseSecretArn": database["DatabaseSecretArn"], "Hostname": config["Hostname"],
        "CertificateArn": config.get("CertificateArn", ""), "HostedZoneId": config.get("HostedZoneId", ""),
        "SecretKeyKmsKeyArn": kms_key, "ImageUri": image, "DesiredCount": desired,
    }, service_role)
    pipeline_parameters = {key: runtime[key] for key in (
        "RepositoryName", "RepositoryUri", "ClusterName", "ServiceName", "TaskDefinitionArn",
        "ExecutionRoleArn", "TaskRoleArn", "TargetGroupArn",
    )}
    pipeline_parameters.update(
        ConnectionArn=config["ConnectionArn"], GitHubOidcProviderArn=config["GitHubOidcProviderArn"],
        TaskSubnetIds=config["TaskSubnetIds"], TaskSecurityGroupId=database["TaskSecurityGroupId"],
    )
    pipeline = deploy("fairstation-stg-pipeline", "pipeline.yaml", pipeline_parameters, service_role)
    print(json.dumps({
        "AWS_REGION": config["Region"], "AWS_RELEASE_ROLE_ARN": pipeline["GitHubReleaseRoleArn"],
        "AWS_PIPELINE_NAME": pipeline["PipelineName"], "ApplicationUrl": runtime["ApplicationUrl"],
        "LoadBalancerDnsName": runtime["LoadBalancerDnsName"],
    }, indent=2))


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stderr or str(error), file=sys.stderr)
        sys.exit(1)
