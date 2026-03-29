resource "aws_dynamodb_table" "visitor_counter" {
  #checkov:skip=CKV_AWS_119:Default DynamoDB encryption is sufficient, CMK adds cost
  name         = "${var.project_name}-visitor-counter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

}