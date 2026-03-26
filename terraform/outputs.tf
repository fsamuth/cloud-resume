output "acm_validation_cname" {
  value = aws_acm_certificate.cert.domain_validation_options
}