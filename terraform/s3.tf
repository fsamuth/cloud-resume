resource "aws_s3_bucket" "resume" {
  #checkov:skip=CKV_AWS_18:Resume bucket access is already tracked via CloudFront access logs
  #checkov:skip=CKV_AWS_144:Cross-region replication is overkill for a personal site
  #checkov:skip=CKV_AWS_145:SSE-S3 is sufficient for a public static site
  #checkov:skip=CKV2_AWS_62:S3 event notifications not needed for a static site
  #checkov:skip=CKV2_AWS_61:No object cleanup needed for a static site with few files
  bucket = var.project_name
}

resource "aws_s3_bucket_versioning" "resume" {
  bucket = aws_s3_bucket.resume.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "resume" {
  bucket = aws_s3_bucket.resume.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.resume.id
  key          = "index.html"
  source       = "../website/index.html"
  content_type = "text/html"
  etag         = filemd5("../website/index.html")

}

resource "aws_s3_bucket_policy" "resume" {
  bucket = aws_s3_bucket.resume.id
  policy = data.aws_iam_policy_document.resume.json
}

data "aws_iam_policy_document" "resume" {
  statement {
    actions = ["s3:GetObject"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.resume.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.resume.arn]
    }
  }

}