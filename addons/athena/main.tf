data "terraform_remote_state" "core" {
  backend = var.core_state_backend
  config  = var.core_state_config
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Athena database names allow only lowercase letters, numbers, and underscores.
  athena_name_prefix   = replace(replace(replace(replace(lower("${var.project_name}_${var.environment}"), "-", "_"), ".", "_"), " ", "_"), "/", "_")
  athena_database_name = var.athena_database_name != null ? var.athena_database_name : "${local.athena_name_prefix}_db"

  data_lake_bucket = data.terraform_remote_state.core.outputs.data_lake_bucket
  data_lake_prefix = trim(data.terraform_remote_state.core.outputs.data_lake_prefix, "/")

  normalized_data_prefix  = local.data_lake_prefix == "" ? "" : "${local.data_lake_prefix}/"
  table_root_location     = "s3://${local.data_lake_bucket}/${local.normalized_data_prefix}"
  table_location_template = "s3://${local.data_lake_bucket}/${local.normalized_data_prefix}year=$${year}/month=$${month}/day=$${day}/"

  normalized_results_prefix = trimsuffix(trimprefix(var.athena_results_prefix, "/"), "/")
  athena_results_location   = "s3://${local.data_lake_bucket}/${local.normalized_results_prefix}/"

  base_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "athena-addon"
  }

  all_tags = merge(local.base_tags, var.additional_tags)
}
