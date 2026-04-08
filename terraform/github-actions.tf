resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
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
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:fsamuth/cloud-resume:ref:refs/heads/main",
        "repo:fsamuth/cloud-resume:pull_request"
      ]
    }
  }

}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-resume"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

}

data "aws_iam_policy_document" "github_actions_policy" {
  #checkov:skip=CKV_AWS_111:Some AWS actions (CloudFront invalidations, ACM list) inherently require * as resource
  #checkov:skip=CKV_AWS_356:Some AWS actions (CloudFront invalidations, ACM list) inherently require * as resource
  statement {
    sid    = "S3Write"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:PutBucketVersioning",
      "s3:PutBucketOwnershipControls",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketTagging",
      "s3:PutObjectTagging"
    ]
    resources = [
      "${aws_s3_bucket.resume.arn}/*",
      "${aws_s3_bucket.tfstate.arn}/*",
      aws_s3_bucket.cloudfront_logs.arn,
      "${aws_s3_bucket.cloudfront_logs.arn}/*"
    ]
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
      "s3:GetObjectTagging",
      "s3:GetBucketOwnershipControls",
      "s3:ListBucketVersions"
    ]
    resources = [
      aws_s3_bucket.resume.arn,
      aws_s3_bucket.tfstate.arn,
      aws_s3_bucket.cloudfront_logs.arn,
      "${aws_s3_bucket.resume.arn}/*",
      "${aws_s3_bucket.tfstate.arn}/*",
      "${aws_s3_bucket.cloudfront_logs.arn}/*"
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
    sid    = "DynamoDBRead"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:DescribeTable",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:ListTagsOfResource",
      "dynamodb:TagResource"
    ]
    resources = [
      aws_dynamodb_table.tfstate_lock.arn,
      aws_dynamodb_table.visitor_counter.arn
    ]
  }

  statement {
    sid    = "DynamoDBVisitorWrite"
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:UpdateTable"
    ]
    resources = [aws_dynamodb_table.visitor_counter.arn]
  }

  statement {
    sid    = "CloudFrontWrite"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:UpdateDistribution",
      "cloudfront:CreateResponseHeadersPolicy",
      "cloudfront:UpdateResponseHeadersPolicy",
      "cloudfront:DeleteResponseHeadersPolicy",
      "cloudfront:TagResource"
    ]
    resources = [
      aws_cloudfront_distribution.resume.arn,
      aws_cloudfront_response_headers_policy.security_headers.arn
    ]
  }

  statement {
    sid    = "CloudFrontRead"
    effect = "Allow"
    actions = [
      "cloudfront:GetDistribution",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:GetResponseHeadersPolicy",
      "cloudfront:ListTagsForResource"
    ]
    resources = [
      aws_cloudfront_distribution.resume.arn,
      aws_cloudfront_origin_access_control.resume.arn,
      aws_cloudfront_response_headers_policy.security_headers.arn
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
    sid    = "ACMRead"
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListTagsForCertificate",
      "acm:AddTagsToCertificate"
    ]
    resources = [aws_acm_certificate.resume.arn]
  }

  statement {
    sid    = "IAMRead"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:GetOpenIDConnectProvider",
      "iam:TagRole",
      "iam:TagOpenIDConnectProvider"
    ]
    resources = [
      aws_iam_role.github_actions.arn,
      aws_iam_openid_connect_provider.github_actions.arn,
      aws_iam_role.lambda.arn
    ]
  }

  statement {
    sid    = "IAMLambdaWrite"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:PassRole"
    ]
    resources = [aws_iam_role.lambda.arn]
  }

  statement {
    sid    = "KMSRead"
    effect = "Allow"
    actions = [
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags",
      "kms:TagResource"
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

  statement {
    sid    = "LambdaWrite"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:DeleteFunction",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:TagResource"
    ]
    resources = [aws_lambda_function.visitor_counter.arn]
  }

  statement {
    sid    = "LambdaRead"
    effect = "Allow"
    actions = [
      "lambda:GetFunction",
      "lambda:GetPolicy",
      "lambda:ListVersionsByFunction",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:GetRuntimeManagementConfig",
      "lambda:GetFunctionConfiguration",
      "lambda:ListFunctionEventInvokeConfigs"
    ]
    resources = [aws_lambda_function.visitor_counter.arn]
  }

  statement {
    sid    = "CloudWatchLogsRead"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:ListTagsLogGroup",
      "logs:ListTagsForResource"
    ]
    resources = ["arn:aws:logs:eu-west-3:*:log-group:*"]
  }

  statement {
    sid    = "CloudWatchLogsWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:TagResource"
    ]
    resources = [aws_cloudwatch_log_group.api_gateway.arn]
  }

  statement {
    sid    = "SQSRead"
    effect = "Allow"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueueTags"
    ]
    resources = [aws_sqs_queue.lambda_dlq.arn]
  }

  statement {
    sid    = "SQSWrite"
    effect = "Allow"
    actions = [
      "sqs:CreateQueue",
      "sqs:DeleteQueue",
      "sqs:SetQueueAttributes",
      "sqs:TagQueue",
      "sqs:UntagQueue"
    ]
    resources = [aws_sqs_queue.lambda_dlq.arn]
  }

  statement {
    sid    = "SNSRead"
    effect = "Allow"
    actions = [
      "sns:GetTopicAttributes",
      "sns:ListTagsForResource",
      "sns:GetSubscriptionAttributes"
    ]
    resources = [aws_sns_topic.alerts.arn]
  }

  statement {
    sid    = "SNSWrite"
    effect = "Allow"
    actions = [
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:Subscribe",
      "sns:Unsubscribe",
      "sns:TagResource"
    ]
    resources = [aws_sns_topic.alerts.arn]
  }

  statement {
    sid    = "CloudWatchAlarmsRead"
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchAlarmsWrite"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:TagResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "BudgetsRead"
    effect = "Allow"
    actions = [
      "budgets:ViewBudget",
      "budgets:DescribeBudgets",
      "budgets:DescribeBudgetActionsForBudget",
      "budgets:DescribeBudgetNotificationsForAccount",
      "budgets:ListTagsForResource"
    ]
    resources = ["arn:aws:budgets::${data.aws_caller_identity.current.account_id}:budget/${var.project_name}-monthly-budget"]
  }

  statement {
    sid    = "BudgetsWrite"
    effect = "Allow"
    actions = [
      "budgets:CreateBudget",
      "budgets:ModifyBudget",
      "budgets:DeleteBudget",
      "budgets:TagResource"
    ]
    resources = ["arn:aws:budgets::${data.aws_caller_identity.current.account_id}:budget/${var.project_name}-monthly-budget"]
  }

  statement {
    sid    = "APIGatewayWrite"
    effect = "Allow"
    actions = [
      "execute-api:*",
      "apigateway:GET",
      "apigateway:POST",
      "apigateway:PUT",
      "apigateway:PATCH",
      "apigateway:DELETE"
    ]
    resources = ["arn:aws:apigateway:*::/*"]
  }

}

resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-resume-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_policy.json

}
