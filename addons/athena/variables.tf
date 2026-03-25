variable "aws_region" {
  description = "AWS region for addon resources."
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

variable "core_state_backend" {
  description = "Terraform backend type used by the core stack state."
  type        = string
  default     = "s3"
}

variable "core_state_config" {
  description = "Backend configuration map used to read core stack state."
  type        = map(string)
  default = {
    bucket = "terraform-tfstates-681108148089-eu-south-1-an"
    key    = "locations-tracker/terraform.tfstate"
    region = "eu-south-1"
  }
}

variable "athena_database_name" {
  description = "Athena database name for location analytics. If null, defaults to a sanitized <project>_<environment>_db."
  type        = string
  default     = null

  validation {
    condition     = var.athena_database_name == null || can(regex("^[a-z0-9_]+$", var.athena_database_name))
    error_message = "athena_database_name must contain only lowercase letters, numbers, and underscore (_)."
  }
}

variable "athena_table_name" {
  description = "Athena external table name for location records."
  type        = string
  default     = "locations"
}

variable "athena_workgroup_name" {
  description = "Athena workgroup name used for query execution."
  type        = string
  default     = "locations-workgroup"
}

variable "athena_results_prefix" {
  description = "Prefix used for Athena query outputs in the data lake bucket."
  type        = string
  default     = "athena-results/"
}

variable "projection_year_start" {
  description = "Start year for partition projection."
  type        = number
  default     = 2020
}

variable "projection_year_end" {
  description = "End year for partition projection."
  type        = number
  default     = 2100
}
