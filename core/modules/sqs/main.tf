variable "queue_name" {
  description = "SQS queue name."
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "SQS visibility timeout in seconds."
  type        = number
}

variable "delay_seconds" {
  description = "Delivery delay for new messages (seconds)."
  type        = number
  default     = 20
}

variable "receive_wait_time_seconds" {
  description = "Long polling wait time (seconds)."
  type        = number
  default     = 5
}

variable "tags" {
  description = "Tags applied to queue."
  type        = map(string)
  default     = {}
}

resource "aws_sqs_queue" "this" {
  name                       = var.queue_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  delay_seconds              = var.delay_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  tags = merge(
    var.tags,
    {
      Name = var.queue_name
    }
  )
}

output "queue_url" {
  description = "SQS queue URL."
  value       = aws_sqs_queue.this.url
}

output "queue_arn" {
  description = "SQS queue ARN."
  value       = aws_sqs_queue.this.arn
}
