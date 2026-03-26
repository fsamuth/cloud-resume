output "acm_validation_cname" {
  value = aws_acm_certificate.cert.domain_validation_options
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}