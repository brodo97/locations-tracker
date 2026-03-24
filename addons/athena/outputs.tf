output "athena_database_name" {
  description = "Athena database name used for location queries."
  value       = aws_athena_database.locations.name
}

output "athena_table_name" {
  description = "Athena table name that maps partitioned JSONL objects."
  value       = aws_glue_catalog_table.locations.name
}

output "athena_workgroup_name" {
  description = "Athena workgroup configured by this addon."
  value       = aws_athena_workgroup.locations.name
}
