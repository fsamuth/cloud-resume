output "github_actions_role_arn" {
  description = "IAM role ARN — set as AWS_ROLE_ARN secret in GitHub"
  value       = aws_iam_role.github_actions.arn
}

output "tfstate_bucket_name" {
  description = "S3 bucket name for remote state — used in terraform/backend.tf"
  value       = aws_s3_bucket.tfstate.id
}
