#!/usr/bin/env python3
"""Operator-only database password rotation during an approved staging outage."""

import argparse
import json
import secrets
import subprocess
import time
import uuid

from pipeline import aws
from provision import outputs


def sensitive_aws(service, operation, request):
    result = subprocess.run(
        ["aws", service, operation, "--cli-input-json", "file:///dev/stdin", "--output", "json", "--no-cli-pager"],
        input=json.dumps(request), capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--maintenance-window", action="store_true", required=True,
                        help="Acknowledge service downtime and that release starts are paused")
    parser.add_argument("--version-id", help="Resume the exact pending version printed by an interrupted attempt")
    parser.add_argument("--desired-count", type=int, help="Original desired count when resuming")
    args = parser.parse_args()
    if args.version_id and args.desired_count is None:
        parser.error("Resume requires the original --desired-count printed by the first attempt")
    if args.desired_count is not None and not 0 <= args.desired_count <= 4:
        parser.error("--desired-count must be between zero and four")
    database = outputs("fairstation-stg-database")
    runtime = outputs("fairstation-stg-runtime")
    if not database or not runtime:
        raise RuntimeError("Provision the dedicated staging stacks first")
    executions = aws("codepipeline", "list-pipeline-executions", pipeline_name="fairstation-stg")
    if any(item["status"] in ("InProgress", "Stopping") for item in executions["pipelineExecutionSummaries"]):
        raise RuntimeError("Wait for all release executions to finish before rotating credentials")
    cluster, service = runtime["ClusterName"], runtime["ServiceName"]
    state = aws("ecs", "describe-services", cluster=cluster, services=[service])["services"][0]
    desired = args.desired_count if args.desired_count is not None else state["desiredCount"]
    version = args.version_id or str(uuid.uuid4())
    print(f"Recovery command: python3 infra/rotate_database_secret.py --maintenance-window --version-id {version} --desired-count {desired}", flush=True)
    secret_arn = database["DatabaseSecretArn"]
    if args.version_id:
        secret = aws("secretsmanager", "get-secret-value", secret_id=secret_arn, version_id=version)
        credentials = json.loads(secret["SecretString"])
    else:
        current = aws("secretsmanager", "get-secret-value", secret_id=secret_arn)
        credentials = json.loads(current["SecretString"])
        credentials["password"] = secrets.token_hex(24)
        sensitive_aws("secretsmanager", "put-secret-value", {
            "SecretId": secret_arn, "ClientRequestToken": version,
            "SecretString": json.dumps(credentials), "VersionStages": ["AWSPENDING"],
        })
    aws("ecs", "update-service", cluster=cluster, service=service, desired_count=0)
    subprocess.run(["aws", "ecs", "wait", "services-stable", "--cluster", cluster, "--services", service], check=True)
    sensitive_aws("rds", "modify-db-instance", {
        "DBInstanceIdentifier": database["DatabaseInstanceId"],
        "MasterUserPassword": credentials["password"], "ApplyImmediately": True,
    })
    # RDS can still report available immediately after accepting the modification.
    deadline = time.monotonic() + 1800
    while time.monotonic() < deadline:
        time.sleep(30)
        instance = aws("rds", "describe-db-instances",
                       db_instance_identifier=database["DatabaseInstanceId"])["DBInstances"][0]
        if (instance["DBInstanceStatus"] == "available"
                and "MasterUserPassword" not in instance.get("PendingModifiedValues", {})):
            break
    else:
        raise RuntimeError("RDS password change did not settle; keep releases paused and use the recovery command")
    versions = aws("secretsmanager", "describe-secret", secret_id=secret_arn)["VersionIdsToStages"]
    current_id = next(key for key, labels in versions.items() if "AWSCURRENT" in labels)
    if current_id != version:
        aws("secretsmanager", "update-secret-version-stage", secret_id=secret_arn,
            version_stage="AWSCURRENT", move_to_version_id=version, remove_from_version_id=current_id)
    if "AWSPENDING" in versions.get(version, []):
        aws("secretsmanager", "update-secret-version-stage", secret_id=secret_arn,
            version_stage="AWSPENDING", remove_from_version_id=version)
    # Scaling back from zero fetches AWSCURRENT without changing the immutable image.
    aws("ecs", "update-service", cluster=cluster, service=service, desired_count=desired)
    subprocess.run(["aws", "ecs", "wait", "services-stable", "--cluster", cluster, "--services", service], check=True)
    print("Database password rotated; service restored to its previous desired count.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.stderr or str(error)) from None
