resource "aws_dynamodb_table" "visitor_counter" {
  name         = "${var.project_name}-visitor-counter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}