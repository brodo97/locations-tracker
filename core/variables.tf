variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-south-1"
}

variable "project_name" {
  description = "Project identifier used for naming and tagging."
  type        = string
}

variable "activity_project_name" {
  description = "Project identifier used for naming the activities data bucket."
  type        = string
  default     = "activities-tracker"
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
  default     = 120
}

variable "lambda_reserved_concurrent_executions" {
  description = "Optional reserved concurrency for Lambda. Set to null to disable."
  type        = number
  default     = null
}

variable "lambda_maximum_concurrency" {
  description = "Maximum concurrency for SQS event source mapping (AWS requires >= 2)."
  type        = number
  default     = 2

  validation {
    condition     = var.lambda_maximum_concurrency >= 2
    error_message = "lambda_maximum_concurrency must be >= 2 for SQS scaling_config.maximum_concurrency."
  }
}

variable "lambda_batch_window_seconds" {
  description = "Maximum batching window for SQS -> Lambda (seconds)."
  type        = number
  default     = 300
}

variable "sqs_visibility_timeout_seconds" {
  description = "SQS visibility timeout in seconds (>= Lambda timeout)."
  type        = number
  default     = 600
}

variable "sqs_batch_size" {
  description = "Number of messages Lambda reads from SQS per batch."
  type        = number
  default     = 1000
}

variable "sqs_delivery_delay_seconds" {
  description = "SQS delivery delay for new messages (seconds)."
  type        = number
  default     = 600
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

variable "api_gateway_enable_logging" {
  description = "Enable API Gateway access and execution logging."
  type        = bool
}

variable "enable_api_gateway" {
  description = "Enable HTTP ingestion through API Gateway."
  type        = bool
  default     = true
}

variable "enable_iot_core" {
  description = "Enable MQTT ingestion through AWS IoT Core."
  type        = bool
  default     = false
}

variable "iot_core_region" {
  description = "AWS region used for IoT Core resources. If null, defaults to aws_region."
  type        = string
  default     = null
}

variable "iot_create_certificate" {
  description = "Create an IoT X.509 certificate and attach the generated policy."
  type        = bool
  default     = false
}

variable "iot_topic_filter" {
  description = "MQTT topic filter used by IoT Core topic rule and client policy."
  type        = string
  default     = "owntracks/#"
}

variable "iot_core_unsupported_regions" {
  description = "Regions known to be unsupported for IoT Core in this project context."
  type        = set(string)
  default     = ["eu-south-1"]
}
