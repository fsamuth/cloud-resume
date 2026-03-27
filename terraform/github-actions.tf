resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-resume"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:fsamuth/cloud-resume:*"]
    }
  }

}

resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-resume-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_policy.json

}

# resource "aws_iam_role_policy_attachment" "github_actions_readonly" {
#   role       = aws_iam_role.github_actions.name
#   policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
# }

data "aws_iam_policy_document" "github_actions_policy" {
  statement {
    sid    = "S3Write"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.resume.arn}/*",
      "${aws_s3_bucket.tfstate.arn}/*"
    ]
  }

  statement {
    sid    = "DynamoDBLock"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = [
      aws_dynamodb_table.tfstate_lock.arn
    ]
  }

  statement {
    sid    = "CloudFrontInvalidation"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation"
    ]
    resources = [
      aws_cloudfront_distribution.resume.arn
    ]
  }

  statement {
    sid    = "ACMWrite"
    effect = "Allow"
    actions = [
      "acm:RequestCertificate",
      "acm:DeleteCertificate"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3Read"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketPolicy",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketWebsite",
      "s3:GetBucketVersioning",
      "s3:GetBucketLogging",
      "s3:GetBucketRequestPayment",
      "s3:GetAccelerateConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketTagging",
      "s3:GetObjectTagging"
    ]
    resources = [
      aws_s3_bucket.resume.arn,
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.resume.arn}/*",
      "${aws_s3_bucket.tfstate.arn}/*"
    ]
  }

  statement {
    sid    = "CloudFrontRead"
    effect = "Allow"
    actions = [
      "cloudfront:GetDistribution",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:ListTagsForResource"
    ]
    resources = [
      aws_cloudfront_distribution.resume.arn,
      aws_cloudfront_origin_access_control.resume.arn
    ]
  }

  statement {
    sid    = "ACMRead"
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListTagsForCertificate"
    ]
    resources = [aws_acm_certificate.cert.arn]
  }

  statement {
    sid    = "IAMRead"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:GetOpenIDConnectProvider"
    ]
    resources = [
      aws_iam_role.github_actions.arn,
      aws_iam_openid_connect_provider.github_actions.arn
    ]
  }

  statement {
    sid    = "DynamoDBRead"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:DescribeTable",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:ListTagsOfResource"
    ]
    resources = [aws_dynamodb_table.tfstate_lock.arn]
  }

  statement {
    sid    = "KMSRead"
    effect = "Allow"
    actions = [
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags"
    ]
    resources = [aws_kms_key.tfstate_key.arn]
  }

  statement {
    sid    = "KMSWrite"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey"
    ]
    resources = [aws_kms_key.tfstate_key.arn]
  }

}