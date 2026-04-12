variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
}

variable "lambda_s3_key" {
  description = "S3 key of the Lambda deployment package"
  type        = string
}

variable "artifacts_bucket" {
  description = "S3 bucket containing Lambda deployment artifacts"
  type        = string
}

variable "create_dashboard" {
  description = "Whether to create a CloudWatch dashboard for this environment"
  type        = bool
  default     = false
}
