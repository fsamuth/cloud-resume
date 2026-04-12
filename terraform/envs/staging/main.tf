module "app" {
  source = "../../modules/app"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project_name     = var.project_name
  domain_name      = var.domain_name
  alert_email      = var.alert_email
  aws_region       = var.aws_region
  lambda_s3_key    = var.lambda_s3_key
  artifacts_bucket = "fsamuth-resume-artifacts"
}
