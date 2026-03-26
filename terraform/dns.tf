resource "aws_acm_certificate" "cert" {
  domain_name       = "cv.samuth.com"
  validation_method = "DNS"
  provider          = aws.us_east_1
}