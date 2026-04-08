resource "aws_acm_certificate" "resume" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  provider          = aws.us_east_1

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "resume" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.resume.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}
