#!/usr/bin/env python3
"""CodeBuild release stages. AWS credentials come exclusively from the project role."""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def aws(service, operation, **arguments):
    command = ["aws", service, operation, "--output", "json", "--no-cli-pager"]
    for key, value in arguments.items():
        command.append("--" + key.replace("_", "-"))
        command.append(json.dumps(value) if isinstance(value, (dict, list)) else str(value))
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return json.loads(result.stdout) if result.stdout.strip() else {}


def save(name, value):
    Path(name).write_text(json.dumps(value, indent=2) + "\n")


def source_sha():
    sha = os.environ["SOURCE_SHA"]
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise RuntimeError("SourceAction must provide the full Git commit SHA")
    if os.environ.get("RELEASE_SHA") != sha:
        raise RuntimeError("An explicit release SHA must match the SourceAction revision")
    return sha


def manifest(artifact, filename):
    data = json.loads((Path(os.environ[f"CODEBUILD_SRC_DIR_{artifact}"]) / filename).read_text())
    if data["source_sha"] != source_sha():
        raise RuntimeError("Artifact source SHA does not match this pipeline execution")
    expected = re.escape(os.environ["REPOSITORY_URI"]) + r"@sha256:[0-9a-f]{64}"
    if not re.fullmatch(expected, data["image_uri"]):
        raise RuntimeError("Artifact must name an immutable digest in this application's repository")
    return data


def build():
    sha = source_sha()
    if os.environ["CODEBUILD_RESOLVED_SOURCE_VERSION"] != sha:
        raise RuntimeError("Checked-out source does not match the requested release SHA")
    repository = os.environ["REPOSITORY_NAME"]
    uri = os.environ["REPOSITORY_URI"]
    tag = "sha-" + sha
    try:
        image = aws("ecr", "describe-images", repository_name=repository, image_ids=[{"imageTag": tag}])
    except subprocess.CalledProcessError as error:
        if "ImageNotFoundException" not in error.stderr:
            raise
        image = None
    if image is None:
        password = subprocess.run(
            ["aws", "ecr", "get-login-password"], check=True, capture_output=True, text=True
        ).stdout
        subprocess.run(
            ["docker", "login", "--username", "AWS", "--password-stdin", uri.split("/")[0]],
            input=password, check=True, text=True,
        )
        subprocess.run([
            "docker", "build", "--platform", "linux/amd64",
            "--label", f"org.opencontainers.image.revision={sha}",
            "--label", "org.opencontainers.image.source=https://github.com/CDLUC3/FAIRStation",
            "--tag", f"{uri}:{tag}", ".",
        ], check=True)
        subprocess.run(["docker", "push", f"{uri}:{tag}"], check=True)
        image = aws("ecr", "describe-images", repository_name=repository, image_ids=[{"imageTag": tag}])
    digest = image["imageDetails"][0]["imageDigest"]
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise RuntimeError("ECR did not return an immutable SHA256 digest")
    data = {"source_sha": sha, "image_uri": f"{uri}@{digest}", "image_tag": tag}
    save("image.json", data)
    print(json.dumps(data), flush=True)


def migrate():
    data = manifest("ImageOutput", "image.json")
    base = aws("ecs", "describe-task-definition", task_definition=os.environ["BASE_TASK_DEFINITION"])["taskDefinition"]
    # Only the registration request's fields; never pass response metadata back to ECS.
    fields = (
        "family", "taskRoleArn", "executionRoleArn", "networkMode", "containerDefinitions",
        "volumes", "placementConstraints", "requiresCompatibilities", "cpu", "memory",
        "pidMode", "ipcMode", "proxyConfiguration", "inferenceAccelerators",
        "ephemeralStorage", "runtimePlatform",
    )
    definition = {key: base[key] for key in fields if key in base}
    if definition["family"] != "fairstation-stg-web":
        raise RuntimeError("Refusing to register a task outside the staging family")
    containers = definition["containerDefinitions"]
    if len(containers) != 1 or containers[0]["name"] != "rails":
        raise RuntimeError("Expected the single FAIR Station Rails container")
    containers[0]["image"] = data["image_uri"]
    environment = [entry for entry in containers[0].get("environment", []) if entry["name"] != "RELEASE_SHA"]
    containers[0]["environment"] = environment + [{"name": "RELEASE_SHA", "value": data["source_sha"]}]
    registered = aws("ecs", "register-task-definition", cli_input_json=definition)["taskDefinition"]
    task_definition = registered["taskDefinitionArn"]
    cluster = os.environ["ECS_CLUSTER"]
    token = hashlib.sha256(os.environ["CODEBUILD_BUILD_ID"].encode()).hexdigest()
    response = aws(
        "ecs", "run-task", cluster=cluster, task_definition=task_definition,
        launch_type="FARGATE", platform_version="1.4.0", count=1, client_token=token,
        network_configuration={"awsvpcConfiguration": {
            "subnets": os.environ["TASK_SUBNETS"].split(","),
            "securityGroups": [os.environ["TASK_SECURITY_GROUP"]],
            "assignPublicIp": "DISABLED",
        }},
        overrides={"containerOverrides": [{"name": "rails", "command": ["bin/rails", "db:prepare"]}]},
        started_by="fairstation-release-migration",
    )
    if response.get("failures") or len(response.get("tasks", [])) != 1:
        raise RuntimeError(f"Migration launch failed: {response}")
    task_arn = response["tasks"][0]["taskArn"]
    print(f"Migration {task_arn}; source {data['source_sha']}; image {data['image_uri']}", flush=True)
    stopped = False
    try:
        deadline = time.monotonic() + 1800
        while time.monotonic() < deadline:
            status = aws("ecs", "describe-tasks", cluster=cluster, tasks=[task_arn])
            if status.get("failures") or len(status.get("tasks", [])) != 1:
                raise RuntimeError(f"Unable to inspect migration: {status}")
            task = status["tasks"][0]
            if task["lastStatus"] == "STOPPED":
                stopped = True
                containers = task.get("containers", [])
                rails = next((container for container in containers if container["name"] == "rails"), {})
                if rails.get("exitCode") != 0 or task.get("stopCode") != "EssentialContainerExited":
                    raise RuntimeError(f"Migration failed: {task.get('stoppedReason')}; containers={containers}")
                break
            time.sleep(10)
        else:
            raise RuntimeError("Migration exceeded the 30-minute limit")
    finally:
        if not stopped:
            aws("ecs", "stop-task", cluster=cluster, task=task_arn, reason="Release migration failed or timed out")
    data.update(task_definition_arn=task_definition, migration_task_arn=task_arn)
    save("deployment.json", data)
    print(json.dumps(data), flush=True)


def deploy():
    data = manifest("DeploymentOutput", "deployment.json")
    task_definition = data["task_definition_arn"]
    definition = aws("ecs", "describe-task-definition", task_definition=task_definition)["taskDefinition"]
    if definition["family"] != "fairstation-stg-web" or definition["containerDefinitions"][0]["image"] != data["image_uri"]:
        raise RuntimeError("Deployment definition differs from the migrated image")
    cluster = os.environ["ECS_CLUSTER"]
    service_name = os.environ["ECS_SERVICE"]
    before = aws("ecs", "describe-services", cluster=cluster, services=[service_name])
    if before.get("failures") or len(before.get("services", [])) != 1:
        raise RuntimeError(f"Cannot inspect service: {before}")
    desired = max(1, before["services"][0]["desiredCount"])
    aws("ecs", "update-service", cluster=cluster, service=service_name,
        task_definition=task_definition, desired_count=desired)
    deadline = time.monotonic() + 1500
    while time.monotonic() < deadline:
        response = aws("ecs", "describe-services", cluster=cluster, services=[service_name])
        if response.get("failures") or len(response.get("services", [])) != 1:
            raise RuntimeError(f"Unable to inspect deployment: {response}")
        service = response["services"][0]
        deployments = service.get("deployments", [])
        primary = next((item for item in deployments if item["status"] == "PRIMARY"), {})
        if primary.get("taskDefinition") != task_definition:
            raise RuntimeError("ECS rolled back or another operator changed the release task definition")
        if primary.get("rolloutState") == "FAILED":
            raise RuntimeError(f"ECS deployment failed: {primary.get('rolloutStateReason')}")
        if (len(deployments) == 1 and primary.get("rolloutState") == "COMPLETED"
                and service["runningCount"] == desired and service["pendingCount"] == 0):
            health = aws("elbv2", "describe-target-health", target_group_arn=os.environ["TARGET_GROUP_ARN"])
            healthy = sum(target["TargetHealth"]["State"] == "healthy" for target in health["TargetHealthDescriptions"])
            if healthy >= desired:
                print(f"Deployed and healthy: {json.dumps(data)}", flush=True)
                return
        time.sleep(15)
    raise RuntimeError("Deployment did not become healthy within 25 minutes; inspect ECS events and logs")


if __name__ == "__main__":
    stages = {"build": build, "migrate": migrate, "deploy": deploy}
    if len(sys.argv) != 2 or sys.argv[1] not in stages:
        sys.exit("Usage: python3 infra/pipeline.py build|migrate|deploy")
    try:
        stages[sys.argv[1]]()
    except subprocess.CalledProcessError as error:
        print(error.stderr or str(error), file=sys.stderr)
        sys.exit(1)
