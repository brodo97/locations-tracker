variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-south-1"
}

variable "project_name" {
  description = "Project identifier used for naming and tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)."
  type        = string
}

variable "additional_tags" {
  description = "Additional tags merged with the default tagging strategy."
  type        = map(string)
  default     = {}
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB."
  type        = number
  default     = 256
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 30
}

variable "lambda_batch_window_seconds" {
  description = "Maximum batching window for SQS -> Lambda (seconds)."
  type        = number
  default     = 20
}

variable "sqs_visibility_timeout_seconds" {
  description = "SQS visibility timeout in seconds (>= Lambda timeout)."
  type        = number
  default     = 120
}

variable "sqs_batch_size" {
  description = "Number of messages Lambda reads from SQS per batch."
  type        = number
  default     = 10
}

variable "sqs_delivery_delay_seconds" {
  description = "SQS delivery delay for new messages (seconds)."
  type        = number
  default     = 20
}

variable "sqs_receive_wait_time_seconds" {
  description = "SQS long polling wait time (seconds)."
  type        = number
  default     = 5
}

variable "s3_lifecycle_days" {
  description = "Optional lifecycle rule to expire objects after N days. Set to 0 to disable."
  type        = number
  default     = 0
}
