output "api_gateway_invoke_url" {
  description = "API Gateway base invoke URL. Use this as OwnTracks HTTP method's URL."
  value       = module.api_gateway.invoke_url
}

output "data_lake_bucket" {
  description = "S3 bucket containing partitioned JSONL location data."
  value       = module.s3.bucket_name
}

output "data_lake_prefix" {
  description = "Optional root prefix for location data inside the data lake bucket."
  value       = ""
}

output "aws_region" {
  description = "AWS region used by the core stack."
  value       = var.aws_region
}
