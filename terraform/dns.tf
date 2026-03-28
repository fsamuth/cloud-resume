resource "aws_acm_certificate" "resume" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  provider          = aws.us_east_1

  lifecycle {
    create_before_destroy = true
  }
}