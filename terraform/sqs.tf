resource "aws_sqs_queue" "lambda_dlq" {
  #checkov:skip=CKV_AWS_27:DLQ only stores Lambda error metadata, not sensitive data
  name = "${var.project_name}-lambda-dlq"
}
