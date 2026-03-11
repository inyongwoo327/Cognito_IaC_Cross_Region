# Lambda 2 — Dispatcher
# Triggered by the /dispatch endpoint. 
# Calls the AWS ECS API to run a standalone Fargate task (RunTask).

import json
import os

import boto3

ECS_CLUSTER_ARN       = os.environ["ECS_CLUSTER_ARN"]
ECS_TASK_DEF_ARN      = os.environ["ECS_TASK_DEF_ARN"]
ECS_SUBNET_ID         = os.environ["ECS_SUBNET_ID"]
ECS_SECURITY_GROUP_ID = os.environ["ECS_SECURITY_GROUP_ID"]
EXECUTING_REGION      = os.environ["EXECUTING_REGION"]

ecs = boto3.client("ecs", region_name=EXECUTING_REGION)


def handler(event, context):
    response = ecs.run_task(
        cluster=ECS_CLUSTER_ARN,
        taskDefinition=ECS_TASK_DEF_ARN,
        launchType="FARGATE",
        networkConfiguration={
            "awsvpcConfiguration": {
                "subnets":         [ECS_SUBNET_ID],
                "securityGroups":  [ECS_SECURITY_GROUP_ID],
                "assignPublicIp":  "ENABLED",
            }
        },
    )

    tasks = response.get("tasks", [])
    task_arn = tasks[0]["taskArn"] if tasks else "none"

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "message":  f"ECS task dispatched from {EXECUTING_REGION}",
            "region":   EXECUTING_REGION,
            "task_arn": task_arn,
        }),
    }