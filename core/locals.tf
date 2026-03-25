locals {
  # Centralized naming logic. All resources must follow <project>-<env>-<resource>.
  name_prefix = "${var.project_name}-${var.environment}"

  # Core resource names
  s3_bucket_name = "${local.name_prefix}-${var.aws_region}"
  sqs_queue_name = "${local.name_prefix}-queue"
  lambda_name    = "${local.name_prefix}-processor"
  lambda_role    = "${local.name_prefix}-lambda-role"
  api_name       = "${local.name_prefix}-api"
  api_role       = "${local.name_prefix}-apigw-role"

  # Consistent tagging
  base_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  all_tags = merge(local.base_tags, var.additional_tags)
}
