# Root wiring for data ingestion pipeline:
# API Gateway and/or IoT Core -> SQS -> Lambda -> S3 (JSONL partitioned by date)

module "s3" {
  source = "./modules/s3"

  bucket_name    = local.s3_bucket_name
  lifecycle_days = var.s3_lifecycle_days
  tags           = local.all_tags
}

module "s3_activity" {
  count  = var.enable_activity_ingestion ? 1 : 0
  source = "./modules/s3"

  bucket_name    = local.activity_bucket_name
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

  function_name                    = local.lambda_name
  role_name                        = local.lambda_role
  bucket_name                      = module.s3.bucket_name
  enable_activity_ingestion        = var.enable_activity_ingestion
  activity_bucket_name             = var.enable_activity_ingestion ? module.s3_activity[0].bucket_name : null
  queue_arn                        = module.sqs.queue_arn
  queue_url                        = module.sqs.queue_url
  memory_size                      = var.lambda_memory_size
  timeout_seconds                  = var.lambda_timeout_seconds
  reserved_concurrent_executions   = var.lambda_reserved_concurrent_executions
  event_source_maximum_concurrency = var.lambda_maximum_concurrency
  batch_size                       = var.sqs_batch_size
  batch_window_seconds             = var.lambda_batch_window_seconds
  tags                             = local.all_tags
}

module "api_gateway" {
  count  = var.enable_api_gateway ? 1 : 0
  source = "./modules/api_gateway"

  api_name                  = local.api_name
  api_role_name             = local.api_role
  queue_arn                 = module.sqs.queue_arn
  queue_url                 = module.sqs.queue_url
  enable_activity_ingestion = var.enable_activity_ingestion
  tags                      = local.all_tags
}

module "iot_core" {
  count  = var.enable_iot_core ? 1 : 0
  source = "./modules/iot_core"

  providers = {
    aws = aws.iot
  }

  topic_rule_name    = local.iot_rule_name
  topic_rule_role    = local.iot_role
  device_policy_name = local.iot_policy
  thing_name         = local.iot_thing
  topic_filter       = var.iot_topic_filter
  queue_arn          = module.sqs.queue_arn
  queue_url          = module.sqs.queue_url
  create_certificate = var.iot_create_certificate
}
