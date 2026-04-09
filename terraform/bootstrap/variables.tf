variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Project name — used for resource naming"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the CI/CD role (owner/repo)"
  type        = string
}

variable "environment" {
  description = "Environment name — used for cost allocation tags"
  type        = string
  default     = "dev"
}
