terraform {
  backend "s3" {
    bucket         = "${var.project_name}-tfstate"
    key            = "resume/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "${var.project_name}-tfstate-lock"
    encrypt        = true
  }
}