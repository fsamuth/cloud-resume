resource "aws_s3_bucket" "artifacts" {
  #checkov:skip=CKV_AWS_18:Internal CI/CD bucket, no compliance requirement
  #checkov:skip=CKV_AWS_144:Cross-region replication is overkill for a personal project
  #checkov:skip=CKV2_AWS_62:S3 event notifications not needed
  #checkov:skip=CKV_AWS_21:Versioning not needed — artifacts are content-addressed by hash
  bucket = "${var.project_name}-artifacts"
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-old-lambda-packages"
    status = "Enabled"

    filter {
      prefix = "lambda/"
    }

    expiration {
      days = 90
    }
  }
}
