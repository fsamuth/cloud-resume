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

data "aws_iam_policy_document" "github_actions_policy" {
  statement {
    sid    = "S3"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketPolicy",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketWebsite",
      "s3:GetBucketVersioning",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketLogging",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration"
    ]
    resources = [
      aws_s3_bucket.resume.arn,
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.resume.arn}/*",
      "${aws_s3_bucket.tfstate.arn}/*"
    ]
  }

  statement {
    sid    = "DynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:ListTagsOfResource"
    ]
    resources = [
      aws_dynamodb_table.tfstate_lock.arn
    ]

  }

  statement {
    sid    = "CloudFrontDistribution"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation"
    ]
    resources = [
      aws_cloudfront_distribution.resume.arn
    ]
  }

  statement {
    sid    = "CloudFrontOAC"
    effect = "Allow"
    actions = [
      "cloudfront:GetOriginAccessControl"
    ]
    resources = [
      aws_cloudfront_origin_access_control.resume.arn
    ]
  }

  statement {
    sid    = "ACM"
    effect = "Allow"
    actions = [
      "acm:GetCertificate",
      "acm:ListTagsForCertificate",
      "acm:DescribeCertificate"
    ]
    resources = [
      aws_acm_certificate.cert.arn
    ]
  }

  statement {
    sid    = "IAMOpenIDConnect"
    effect = "Allow"
    actions = [
      "iam:GetOpenIDConnectProvider",
    ]
    resources = [
      aws_iam_openid_connect_provider.github_actions.arn
    ]
  }

  statement {
    sid    = "IAMRole"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies"
    ]
    resources = [
      aws_iam_role.github_actions.arn
    ]
  }
}