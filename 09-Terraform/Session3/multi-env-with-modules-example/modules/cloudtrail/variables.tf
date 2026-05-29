variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket to store CloudTrail logs."
}

variable "force_destroy_bucket" {
  type        = bool
  default     = false
  description = "Set to true to empty and delete the bucket during terraform destroy."
}

variable "queue_name" {
  type        = string
  default     = "cloudtrail-siem-notification-queue"
  description = "The name of the SQS queue used by the SIEM."
}

variable "queue_message_retention" {
  type        = number
  default     = 345600 # 4 days
  description = "How long the SQS queue keeps messages before expiring (in seconds)."
}

variable "trail_name" {
  type        = string
  default     = "management-events-trail"
  description = "The name of the CloudTrail instance."
}

variable "is_multi_region" {
  type        = bool
  default     = true
  description = "Specifies whether the trail is created in all regions."
}

variable "include_global_events" {
  type        = bool
  default     = true
  description = "Specifies whether global service events (like IAM) are included."
}
