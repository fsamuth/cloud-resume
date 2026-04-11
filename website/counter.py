import boto3
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

table_name = os.environ["TABLE_NAME"]
table = boto3.resource("dynamodb").Table(table_name)

def handler(event, context):
    try:
        response = table.update_item(
            Key={"id": "counter"},
            UpdateExpression="ADD #v :inc",
            ExpressionAttributeNames={"#v": "views"},
            ExpressionAttributeValues={":inc": 1},
            ReturnValues="UPDATED_NEW"
        )
        return {
            "statusCode": 200,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"views": int(response["Attributes"]["views"])})
        }
    except Exception as e:
        logger.exception("Failed to update visitor counter: %s", e)
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": "Internal server error"})
        }
