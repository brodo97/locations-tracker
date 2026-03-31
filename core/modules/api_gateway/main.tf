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

variable "enable_logging" {
  description = "Enable API Gateway access logs and execution logging."
  type        = bool
  default     = false
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
  name         = "OwnTracksPayload"
  content_type = "application/json"
  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "OwnTracks payload"
    type      = "object"
    properties = {
      "_type" = {
        type = "string"
        enum = [
          "beacon",
          "card",
          "cmd",
          "configuration",
          "encrypted",
          "location",
          "lwt",
          "request",
          "status",
          "steps",
          "transition",
          "waypoint",
          "waypoints",
          "activity"
        ]
      }
      "lat"       = { type = "number", minimum = -90, maximum = 90 }
      "lon"       = { type = "number", minimum = -180, maximum = 180 }
      "tst"       = { type = "integer" }
      "act"       = { type = "integer" }
      "wtst"      = { type = "integer" }
      "event"     = { type = "string" }
      "desc"      = { type = "string" }
      "waypoints" = { type = "array" }
      "action"    = { type = "string" }
      "data"      = { type = "string" }
      "tid"       = { type = "string" }
      "request"   = {}
      "steps"     = {}
      "_id"       = { type = "string" }
      "batt"      = { type = "integer", minimum = 0, maximum = 100 }
      "vel"       = { type = "number", minimum = 0 }
      "cog"       = { type = "number", minimum = 0, maximum = 360 }
      "conn"      = { type = "string" }
    }
    required = ["_type"]
    oneOf = [
      {
        type = "object"
        properties = {
          "_type" = { enum = ["location"] }
        }
        required             = ["_type", "lat", "lon", "tst"]
        additionalProperties = true
      },
      {
        type = "object"
        properties = {
          "_type" = { enum = ["transition"] }
        }
        required             = ["_type", "tst", "wtst", "event"]
        additionalProperties = true
      },
      {
        type = "object"
        properties = {
          "_type" = { enum = ["waypoint"] }
        }
        required             = ["_type", "desc", "tst"]
        additionalProperties = true
      },
      {
        type = "object"
        properties = {
          "_type" = { enum = ["waypoints"] }
        }
        required             = ["_type", "waypoints"]
        additionalProperties = true
      },
      {
        type = "object"
        properties = {
          "_type" = { enum = ["cmd"] }
        }
        required             = ["_type", "action"]
        additionalProperties = true
      },
      {
        type = "object"
        properties = {
          "_type" = { enum = ["encrypted"] }
        }
        required             = ["_type", "data"]
        additionalProperties = true
      },
      {
        type = "object"
        properties = {
          "_type" = { enum = ["card"] }
        }
        required             = ["_type", "tid"]
        additionalProperties = true
      },
      {
        type = "object"
        properties = {
          "_type" = { enum = ["lwt"] }
        }
        required             = ["_type", "tst"]
        additionalProperties = true
      },
      {
        type = "object"
        properties = {
          "_type" = { enum = ["steps"] }
        }
        required             = ["_type", "tst", "steps"]
        additionalProperties = true
      },
      {
        type = "object"
        properties = {
          "_type" = { enum = ["request"] }
        }
        required             = ["_type", "request"]
        additionalProperties = true
      },
      {
        type = "object"
        properties = {
          "_type" = { enum = ["status"] }
        }
        required             = ["_type"]
        additionalProperties = true
      },
      {
        type = "object"
        properties = {
          "_type" = { enum = ["configuration"] }
        }
        required             = ["_type"]
        additionalProperties = true
      },
      {
        type = "object"
        properties = {
          "_type" = { enum = ["beacon"] }
        }
        required             = ["_type", "tst"]
        additionalProperties = true
      },
      {
        type = "object"
        properties = {
          "_type" = { enum = ["activity"] }
        }
        additionalProperties = true
      }
    ]
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

resource "aws_cloudwatch_log_group" "apigw_access" {
  count = var.enable_logging ? 1 : 0

  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_iam_role" "apigw_logs" {
  count = var.enable_logging ? 1 : 0

  name               = "${var.api_name}-logs-role"
  assume_role_policy = data.aws_iam_policy_document.apigw_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "apigw_logs" {
  count = var.enable_logging ? 1 : 0

  role       = aws_iam_role.apigw_logs[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  count = var.enable_logging ? 1 : 0

  cloudwatch_role_arn = aws_iam_role.apigw_logs[0].arn
}

resource "aws_api_gateway_stage" "this" {
  stage_name    = "v1"
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id

  dynamic "access_log_settings" {
    for_each = var.enable_logging ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.apigw_access[0].arn
      format = jsonencode({
        requestId      = "$context.requestId"
        ip             = "$context.identity.sourceIp"
        caller         = "$context.identity.caller"
        user           = "$context.identity.user"
        requestTime    = "$context.requestTime"
        httpMethod     = "$context.httpMethod"
        resourcePath   = "$context.resourcePath"
        status         = "$context.status"
        protocol       = "$context.protocol"
        responseLength = "$context.responseLength"
        integrationId  = "$context.integration.requestId"
      })
    }
  }

  tags = var.tags
  depends_on = [aws_api_gateway_account.this]
}

resource "aws_api_gateway_method_settings" "logging" {
  count = var.enable_logging ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    logging_level      = "INFO"
    data_trace_enabled = true
    metrics_enabled    = true
  }

  depends_on = [aws_api_gateway_account.this]
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

output "invoke_url" {
  description = "API Gateway invoke URL."
  value       = aws_api_gateway_stage.this.invoke_url
}
