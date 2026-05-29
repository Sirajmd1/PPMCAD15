output "cloudtrail_arn" {
  value       = aws_cloudtrail.main_trail.arn
  description = "The ARN of the deployed CloudTrail."
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.ct_logs.arn
  description = "The ARN of the CloudTrail storage S3 bucket."
}

output "sqs_queue_arn" {
  value       = aws_sqs_queue.ct_siem_queue.arn
  description = "The ARN of the SQS queue."
}

output "sqs_queue_url" {
  value       = aws_sqs_queue.ct_siem_queue.id
  description = "The URL of the SQS queue for SIEM polling configuration."
}
