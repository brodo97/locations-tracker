# Root wiring for data ingestion pipeline:
# API Gateway -> SQS -> Lambda -> S3 (JSONL partitioned by date)

module "s3" {
  source = "./modules/s3"

  bucket_name    = local.s3_bucket_name
  lifecycle_days = var.s3_lifecycle_days
  tags           = local.all_tags
}

module "sqs" {
  source = "./modules/sqs"

  queue_name                 = local.sqs_queue_name
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  delay_seconds              = var.sqs_delivery_delay_seconds
  receive_wait_time_seconds  = var.sqs_receive_wait_time_seconds
  tags                       = local.all_tags
}

module "lambda" {
  source = "./modules/lambda"

  function_name         = local.lambda_name
  role_name             = local.lambda_role
  bucket_name           = module.s3.bucket_name
  queue_arn             = module.sqs.queue_arn
  queue_url             = module.sqs.queue_url
  memory_size           = var.lambda_memory_size
  timeout_seconds       = var.lambda_timeout_seconds
  batch_size            = var.sqs_batch_size
  batch_window_seconds  = var.lambda_batch_window_seconds
  tags                  = local.all_tags
}

module "api_gateway" {
  source = "./modules/api_gateway"

  api_name      = local.api_name
  api_role_name = local.api_role
  queue_arn     = module.sqs.queue_arn
  queue_url     = module.sqs.queue_url
  tags          = local.all_tags
}
