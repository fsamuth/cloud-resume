resource "aws_cloudfront_origin_access_control" "resume" {
  name                              = "${var.project_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_protocol                  = "sigv4"
  signing_behavior                  = "always"
}

resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "${var.project_name}-security-headers"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
      preload                    = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
    content_security_policy {
      content_security_policy = "default-src 'self'; style-src 'self' https://cdnjs.cloudflare.com; font-src https://cdnjs.cloudflare.com; img-src 'self' data:; script-src 'self'; object-src 'none';"
      override                = true
    }
  }
}

resource "aws_cloudfront_distribution" "resume" {
  #checkov:skip=CKV_AWS_68:WAF costs ~$5/month minimum, not justified for a personal site
  #checkov:skip=CKV2_AWS_47:WAF not configured, Log4j AMR rule not applicable
  #checkov:skip=CKV_AWS_310:Origin failover is overkill for a single S3 static site
  aliases             = [var.domain_name]
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.resume.bucket_regional_domain_name
    origin_id                = "s3-resume"
    origin_access_control_id = aws_cloudfront_origin_access_control.resume.id
  }
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["FR"]
    }
  }
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.resume.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "s3-resume"
    viewer_protocol_policy     = "redirect-to-https"
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  logging_config {
    bucket = aws_s3_bucket.cloudfront_logs.bucket_domain_name
  }

}
