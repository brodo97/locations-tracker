locals {
  # Centralized naming logic. All resources must follow <project>-<env>-<resource>.
  name_prefix = "${var.project_name}-${var.environment}"

  # Core resource names
  s3_bucket_name       = "${local.name_prefix}-${var.aws_region}"
  activity_name_prefix = "${var.activity_project_name}-${var.environment}"
  activity_bucket_name = "${local.activity_name_prefix}-${var.aws_region}"
  sqs_queue_name       = "${local.name_prefix}-queue"
  lambda_name          = "${local.name_prefix}-processor"
  lambda_role          = "${local.name_prefix}-lambda-role"
  api_name             = "${local.name_prefix}-api"
  api_role             = "${local.name_prefix}-apigw-role"
  iot_rule_name        = replace("${local.name_prefix}-iot-rule", "-", "_")
  iot_role             = "${local.name_prefix}-iot-role"
  iot_policy           = "${local.name_prefix}-iot-policy"
  iot_thing            = "${local.name_prefix}-thing"

  # IoT Core can run in a dedicated fallback region.
  iot_effective_region = coalesce(var.iot_core_region, var.aws_region)

  # Consistent tagging
  base_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  all_tags = merge(local.base_tags, var.additional_tags)
}
