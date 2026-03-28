data "archive_file" "counter" {
  type        = "zip"
  source_file = "../website/counter.py"
  output_path = "/tmp/counter.zip"
}

resource "aws_iam_role" "lambda" {
  name               = "lambda-resume"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_lambda_function" "visitor_counter" {
  function_name    = "visitor-counter"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.counter.output_path
  source_code_hash = data.archive_file.counter.output_base64sha256
  runtime          = "python3.13"
  handler          = "counter.handler"
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitor_counter.name
    }
  }
}

resource "aws_iam_role_policy" "lambda_visitor_counter_policy" {
  name   = "lambda-visitor-counter-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_visitor_counter_policy.json

}

data "aws_iam_policy_document" "lambda_visitor_counter_policy" {
  statement {
    sid    = "DynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem"
    ]
    resources = [aws_dynamodb_table.visitor_counter.arn]
  }
  statement {
    sid    = "Lambda"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}