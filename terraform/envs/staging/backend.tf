terraform {
  backend "s3" {
    bucket       = "fsamuth-resume-tfstate"
    key          = "staging/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }
}
