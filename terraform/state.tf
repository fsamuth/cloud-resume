resource "aws_s3_bucket" "tfstate" {
  #checkov:skip=CKV_AWS_18:Internal infrastructure bucket, no compliance requirement
  #checkov:skip=CKV_AWS_144:Cross-region replication is overkill for a personal project
  #checkov:skip=CKV2_AWS_62:S3 event notifications not needed for a state bucket
  #checkov:skip=CKV2_AWS_61:State file versions should be retained, not expired
  bucket = "${var.project_name}-tfstate"
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "tfstate_lock" {
  #checkov:skip=CKV_AWS_119:Default DynamoDB encryption is sufficient, CMK adds cost
  name         = "${var.project_name}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

}

resource "aws_kms_key" "tfstate_key" {
  description             = "KMS key for Terraform state bucket encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 10
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate_key" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.tfstate_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

data "aws_caller_identity" "current" {}
