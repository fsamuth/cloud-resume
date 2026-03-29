import json
import os
import boto3
import pytest
from moto import mock_aws

os.environ["AWS_DEFAULT_REGION"] = "eu-west-3"
os.environ["AWS_ACCESS_KEY_ID"] = "fake"
os.environ["AWS_SECRET_ACCESS_KEY"] = "fake"
os.environ["TABLE_NAME"] = "test-visitor-counter"

@pytest.fixture
def dynamodb_table():
    with mock_aws():
        dynamodb = boto3.resource("dynamodb", region_name="eu-west-3")
        table = dynamodb.create_table(
            TableName="test-visitor-counter",
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST"
        )
        yield table

def test_first_visit_returns_one(dynamodb_table):
    with mock_aws():
        from counter import handler
        response = handler({}, {})
        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["views"] == 1

def test_second_visit_increments(dynamodb_table):
    with mock_aws():
        from counter import handler
        handler({}, {})
        response = handler({}, {})
        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["views"] == 2
