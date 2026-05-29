# 1. Fetch current AWS account details
data "aws_caller_identity" "current" {}

# 2. Create S3 Bucket and Lifecycle Policy for CloudTrail Logs
resource "aws_s3_bucket" "ct_logs" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy_bucket
}

resource "aws_s3_bucket_policy" "ct_logs_policy" {
  bucket = aws_s3_bucket.ct_logs.id
  policy = data.aws_iam_policy_document.ct_bucket_policy.json
}

data "aws_iam_policy_document" "ct_bucket_policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["://amazonaws.com"]
    }
    actions = ["s3:GetBucketAcl", "s3:PutObject"]
    resources = [
      aws_s3_bucket.ct_logs.arn,
      "${aws_s3_bucket.ct_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

# 3. Create SQS Queue and Access Policy for SIEM
resource "aws_sqs_queue" "ct_siem_queue" {
  name                      = var.queue_name
  message_retention_seconds = var.queue_message_retention
}

resource "aws_sqs_queue_policy" "ct_sqs_policy" {
  queue_url = aws_sqs_queue.ct_siem_queue.id
  policy    = data.aws_iam_policy_document.ct_sqs_policy_doc.json
}

data "aws_iam_policy_document" "ct_sqs_policy_doc" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["://amazonaws.com"]
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.ct_siem_queue.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.ct_logs.arn]
    }
  }
}

# 4. Configure S3 Bucket Notification to target SQS
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.ct_logs.id
  queue {
    queue_arn     = aws_sqs_queue.ct_siem_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".json.gz"
  }
}

# 5. Create CloudTrail
resource "aws_cloudtrail" "main_trail" {
  name                          = var.trail_name
  s3_bucket_name                = aws_s3_bucket.ct_logs.id
  is_multi_region_trail         = var.is_multi_region
  include_global_service_events = var.include_global_events
}
