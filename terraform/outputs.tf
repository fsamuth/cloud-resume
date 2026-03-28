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