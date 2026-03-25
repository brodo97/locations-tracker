variable "api_name" {
  description = "API Gateway name."
  type        = string
}

variable "api_role_name" {
  description = "IAM role name for API Gateway to access SQS."
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

variable "tags" {
  description = "Tags applied to API resources."
  type        = map(string)
  default     = {}
}

locals {
  # API path for ingesting location payloads
  resource_path         = "locations"
  queue_name            = split("/", var.queue_url)[length(split("/", var.queue_url)) - 1]
  ack_response_template = <<EOF
#set($messageId = "")
#set($fromPath = $input.path('$.SendMessageResponse.SendMessageResult.MessageId'))
#if($fromPath != "" && $fromPath != "null")
  #set($messageId = $fromPath)
#else
  #set($raw = $input.body)
  #set($startTag = "<MessageId>")
  #set($endTag = "</MessageId>")
  #set($start = $raw.indexOf($startTag))
  #if($start != -1)
    #set($from = $start + $startTag.length())
    #set($end = $raw.indexOf($endTag, $from))
    #if($end != -1)
      #set($messageId = $raw.substring($from, $end))
    #end
  #end
#end
{
  "_type": "location_ack",
  "message_id": "$util.escapeJavaScript($messageId)"
}
EOF
}

data "aws_iam_policy_document" "apigw_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "apigw" {
  name               = var.api_role_name
  assume_role_policy = data.aws_iam_policy_document.apigw_assume.json

  tags = var.tags
}

data "aws_iam_policy_document" "apigw_sqs" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage"
    ]
    resources = [var.queue_arn]
  }
}

resource "aws_iam_role_policy" "apigw_sqs" {
  name   = "${var.api_name}-sqs-policy"
  role   = aws_iam_role.apigw.id
  policy = data.aws_iam_policy_document.apigw_sqs.json
}

resource "aws_api_gateway_rest_api" "this" {
  name = var.api_name

  tags = var.tags
}

resource "aws_api_gateway_model" "location_payload" {
  rest_api_id  = aws_api_gateway_rest_api.this.id
  name         = "LocationPayload"
  content_type = "application/json"
  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "OwnTracks location payload"
    type      = "object"
    required  = ["_type", "lat", "lon", "tst"]
    properties = {
      "_type" = { type = "string" }
      "_id"   = { type = "string" }
      "lat"   = { type = "number", minimum = -90, maximum = 90 }
      "lon"   = { type = "number", minimum = -180, maximum = 180 }
      "tst"   = { type = "integer" }
      "batt"  = { type = "integer", minimum = 0, maximum = 100 }
      "vel"   = { type = "number", minimum = 0 }
      "cog"   = { type = "number", minimum = 0, maximum = 360 }
      "conn"  = { type = "string", enum = ["m", "w"] }
    }
    additionalProperties = true
  })
}

resource "aws_api_gateway_request_validator" "body_only" {
  rest_api_id                 = aws_api_gateway_rest_api.this.id
  name                        = "validate-json-body"
  validate_request_body       = true
  validate_request_parameters = false
}

resource "aws_api_gateway_resource" "locations" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = local.resource_path
}

resource "aws_api_gateway_method" "post" {
  rest_api_id          = aws_api_gateway_rest_api.this.id
  resource_id          = aws_api_gateway_resource.locations.id
  http_method          = "POST"
  authorization        = "NONE"
  request_validator_id = aws_api_gateway_request_validator.body_only.id
  request_models = {
    "application/json" = aws_api_gateway_model.location_payload.name
  }
}

resource "aws_api_gateway_integration" "sqs" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.locations.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sqs:path/${data.aws_caller_identity.current.account_id}/${local.queue_name}"
  credentials             = aws_iam_role.apigw.arn

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  # API Gateway -> SQS: wraps raw JSON body into SendMessage
  request_templates = {
    "application/json" = "Action=SendMessage&Version=2012-11-05&MessageBody=$util.urlEncode($input.body)"
  }
}

resource "aws_api_gateway_method_response" "post_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.locations.id
  http_method = aws_api_gateway_method.post.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "post_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.locations.id
  http_method = aws_api_gateway_method.post.http_method
  status_code = aws_api_gateway_method_response.post_200.status_code

  response_templates = {
    "application/json" = local.ack_response_template
  }

  depends_on = [aws_api_gateway_integration.sqs]
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Forces redeploy on configuration changes
  triggers = {
    redeployment = sha1(jsonencode({
      rest_api_id        = aws_api_gateway_rest_api.this.id
      resource_id        = aws_api_gateway_resource.locations.id
      method_id          = aws_api_gateway_method.post.id
      integration        = aws_api_gateway_integration.sqs.id
      request_validator  = aws_api_gateway_request_validator.body_only.id
      request_model_name = aws_api_gateway_model.location_payload.name
      request_model_sha1 = sha1(aws_api_gateway_model.location_payload.schema)
      ack_template_sha1  = sha1(local.ack_response_template)
    }))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.sqs,
    aws_api_gateway_method_response.post_200,
    aws_api_gateway_integration_response.post_200
  ]
}

resource "aws_api_gateway_stage" "this" {
  stage_name    = "v1"
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id

  tags = var.tags
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

output "invoke_url" {
  description = "API Gateway invoke URL."
  value       = aws_api_gateway_stage.this.invoke_url
}
