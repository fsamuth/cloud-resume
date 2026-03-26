resource "aws_acm_certificate" "cert" {
  domain_name       = "fidele.samuth.com"
  validation_method = "DNS"
  provider          = aws.us_east_1

  lifecycle {
    create_before_destroy = true
  }
}