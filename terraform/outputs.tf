output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "s3_bucket_name" {
  value = aws_s3_bucket.resume.id
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.resume.id
}

output "api_gateway_url" {
  value = aws_apigatewayv2_stage.visitor_counter.invoke_url
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.resume.domain_name
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.visitor_counter.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.visitor_counter.function_name
}