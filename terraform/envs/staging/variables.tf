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

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "lambda_s3_key" {
  description = "S3 key of the Lambda deployment package"
  type        = string
}

variable "basic_auth_credentials" {
  description = "Base64-encoded basic auth credentials (user:pass). Leave empty to disable."
  type        = string
  default     = ""
  sensitive   = true
}
