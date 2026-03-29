resource "aws_s3_bucket" "cloudfront_logs" {
  #checkov:skip=CKV_AWS_18:Logging the logging bucket is circular
  #checkov:skip=CKV_AWS_21:Versioning on a log bucket adds cost, logs are append-only
  #checkov:skip=CKV_AWS_144:Cross-region replication is overkill for a personal project
  #checkov:skip=CKV_AWS_145:SSE-S3 is sufficient for access logs, KMS not justified
  #checkov:skip=CKV2_AWS_62:S3 event notifications not needed for a log bucket
  bucket = "${var.project_name}-cloudfront-logs"
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  #checkov:skip=CKV2_AWS_65:BucketOwnerPreferred is required for CloudFront access logging ACLs
  bucket = aws_s3_bucket.cloudfront_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]
  bucket     = aws_s3_bucket.cloudfront_logs.id
  acl        = "log-delivery-write"
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  #checkov:skip=CKV_AWS_158:KMS encryption for logs adds cost with no benefit at this scale
  #checkov:skip=CKV_AWS_338:30 days retention is sufficient for a personal project
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = 30
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"
    expiration {
      days = 90
    }
  }
}
