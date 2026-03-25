variable "bucket_name" {
  description = "S3 bucket name for location storage."
  type        = string
}

variable "lifecycle_days" {
  description = "Expire objects after N days. Set to 0 to disable."
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags applied to bucket."
  type        = map(string)
  default     = {}
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  tags = merge(
    var.tags,
    {
      Name = var.bucket_name
    }
  )
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  # Rule 1: Always keep only the latest 3 noncurrent versions
  rule {
    id     = "retain-latest-3-noncurrent"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      newer_noncurrent_versions = 3
      noncurrent_days           = 1
    }
  }

  # Rule 2: Optional current-version expiration by days
  dynamic "rule" {
    for_each = var.lifecycle_days > 0 ? [1] : []
    content {
      id     = "expire-current-objects"
      status = "Enabled"

      filter {}

      expiration {
        days = var.lifecycle_days
      }
    }
  }
}

output "bucket_name" {
  description = "S3 bucket name."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "S3 bucket ARN."
  value       = aws_s3_bucket.this.arn
}
