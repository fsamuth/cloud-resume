output "s3_bucket_name" {
  value = module.app.s3_bucket_name
}

output "cloudfront_distribution_id" {
  value = module.app.cloudfront_distribution_id
}

output "api_gateway_url" {
  value = module.app.api_gateway_url
}

output "cloudfront_domain_name" {
  value = module.app.cloudfront_domain_name
}

output "lambda_s3_key" {
  value = module.app.lambda_s3_key
}
