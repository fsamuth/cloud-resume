terraform {

  required_version = ">= 1.11.0"

  backend "s3" {
    bucket         = "fsamuth-resume-tfstate"
    key            = "resume/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "fsamuth-resume-tfstate-lock"
    encrypt        = true
  }
}