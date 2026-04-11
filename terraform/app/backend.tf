terraform {
  backend "s3" {
    bucket       = "fsamuth-resume-tfstate"
    key          = "resume/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }
}
