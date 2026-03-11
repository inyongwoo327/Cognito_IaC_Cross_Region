# Lambda 1 - Greeter
import json
import os
import uuid
from datetime import datetime, timezone

import boto3

DYNAMODB_TABLE   = os.environ["DYNAMODB_TABLE"]
SNS_TOPIC_ARN    = os.environ["SNS_TOPIC_ARN"]
YOUR_EMAIL       = os.environ["YOUR_EMAIL"]
GITHUB_REPO      = os.environ["GITHUB_REPO"]
EXECUTING_REGION = os.environ["EXECUTING_REGION"]

dynamodb = boto3.resource("dynamodb", region_name=EXECUTING_REGION)
# SNS topic lives in us-east-1, always
sns = boto3.client("sns", region_name="us-east-1")


def handler(event, context):
    record_id = str(uuid.uuid4())
    timestamp = datetime.now(timezone.utc).isoformat()

    # Write to regional DynamoDB
    table = dynamodb.Table(DYNAMODB_TABLE)
    table.put_item(
        Item={
            "id":        record_id,
            "timestamp": timestamp,
            "region":    EXECUTING_REGION,
            "source":    "greeter-lambda",
        }
    )

    # Publish SNS topic
    sns_payload = {
        "email":  YOUR_EMAIL,
        "source": "Lambda",
        "region": EXECUTING_REGION,
        "repo":   GITHUB_REPO,
    }
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Message=json.dumps(sns_payload),
    )
    # Returns 200 with region name
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "message": f"Hello from {EXECUTING_REGION}!",
            "region":  EXECUTING_REGION,
            "id":      record_id,
        }),
    }