resource "aws_route53_zone" "resume" {
  name = var.domain_name
}

# ACM certificate validation record
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.resume.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.resume.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# CloudFront alias record
resource "aws_route53_record" "resume" {
  zone_id = aws_route53_zone.resume.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.resume.domain_name
    zone_id                = aws_cloudfront_distribution.resume.hosted_zone_id
    evaluate_target_health = false
  }
}
