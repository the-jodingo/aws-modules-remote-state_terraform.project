resource "aws_kms_key" "state" {
  description             = "Encryption key for ${var.state_bucket_name} Terraform state"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

# An explicit key policy is what actually authorises use of the key. Without one
# the key falls back to the account default, which grants broad access and cannot
# be audited per key.
resource "aws_kms_key_policy" "state" {
  key_id = aws_kms_key.state.id
  policy = data.aws_iam_policy_document.state_key.json
}

data "aws_iam_policy_document" "state_key" {
  statement {
    sid    = "EnableRootAccountAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowStateBucketUse"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.state.arn]
    }
  }
}

resource "aws_kms_alias" "state" {
  name          = "alias/${var.state_bucket_name}-state"
  target_key_id = aws_kms_key.state.key_id
}

data "aws_caller_identity" "current" {}

# Access logs are stored in a separate bucket so that logging into the state
# bucket does not create a recursive dependency.
#checkov:skip=CKV2_AWS_62:Event notifications need a consumer endpoint. This lab has none,
# and wiring one purely to satisfy the check would add an unused SNS topic.
resource "aws_s3_bucket" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket        = "${var.state_bucket_name}-logs"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACLs stay disabled on the log bucket. S3 log delivery writes through a bucket
# policy granted to the logging service principal instead, which is the only
# ownership model that works when ACLs are off.
resource "aws_s3_bucket_ownership_controls" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.access_log_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "logs_bucket" {
  count = var.enable_access_logging ? 1 : 0

  statement {
    sid    = "AllowS3LogDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs[0].arn}/state-access/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.state.arn]
    }
  }

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.logs[0].arn,
      "${aws_s3_bucket.logs[0].arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id
  policy = data.aws_iam_policy_document.logs_bucket[0].json

  depends_on = [
    aws_s3_bucket_public_access_block.logs,
    aws_s3_bucket_ownership_controls.logs,
  ]
}

resource "aws_s3_bucket_logging" "state" {
  count = var.enable_access_logging ? 1 : 0

  bucket        = aws_s3_bucket.state.id
  target_bucket = aws_s3_bucket.logs[0].id
  target_prefix = "state-access/"

  depends_on = [aws_s3_bucket_policy.logs]
}
