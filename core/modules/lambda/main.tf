variable "function_name" {
  description = "Lambda function name."
  type        = string
}

variable "role_name" {
  description = "IAM role name for Lambda."
  type        = string
}

variable "bucket_name" {
  description = "Target S3 bucket name."
  type        = string
}

variable "queue_arn" {
  description = "SQS queue ARN."
  type        = string
}

variable "queue_url" {
  description = "SQS queue URL."
  type        = string
}

variable "memory_size" {
  description = "Lambda memory size in MB."
  type        = number
}

variable "timeout_seconds" {
  description = "Lambda timeout in seconds."
  type        = number
}

variable "reserved_concurrent_executions" {
  description = "Optional reserved concurrency. Set to null to disable."
  type        = number
  default     = null
}

variable "event_source_maximum_concurrency" {
  description = "Maximum concurrency for SQS event source mapping (AWS requires >= 2)."
  type        = number
  default     = 2

  validation {
    condition     = var.event_source_maximum_concurrency >= 2
    error_message = "event_source_maximum_concurrency must be >= 2 for SQS event source mapping scaling_config."
  }
}

variable "batch_size" {
  description = "SQS batch size for Lambda event source mapping."
  type        = number
}

variable "batch_window_seconds" {
  description = "Maximum batching window for SQS -> Lambda (seconds)."
  type        = number
  default     = 20
}

variable "tags" {
  description = "Tags applied to Lambda resources."
  type        = map(string)
  default     = {}
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility"
    ]
    resources = [var.queue_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "inline" {
  name   = "${var.function_name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.this.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.13"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  memory_size = var.memory_size
  timeout     = var.timeout_seconds
  # Keep reserved concurrency optional to avoid account-wide quota issues on low-limit accounts.
  reserved_concurrent_executions = var.reserved_concurrent_executions != null ? var.reserved_concurrent_executions : null

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
    }
  }

  tags = var.tags
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn                   = var.queue_arn
  function_name                      = aws_lambda_function.this.arn
  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = var.batch_window_seconds
  # Prefer event source scaling over reserved concurrency: it limits poller parallelism safely.
  scaling_config {
    maximum_concurrency = var.event_source_maximum_concurrency
  }
  enabled = true
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = 30
  tags              = var.tags
}

output "function_arn" {
  description = "Lambda function ARN."
  value       = aws_lambda_function.this.arn
}
