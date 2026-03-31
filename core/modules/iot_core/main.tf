terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "topic_rule_name" {
  description = "IoT Core topic rule name."
  type        = string
}

variable "topic_rule_role" {
  description = "IAM role name assumed by IoT Core for SQS publish."
  type        = string
}

variable "device_policy_name" {
  description = "IoT policy name attached to device certificates."
  type        = string
}

variable "topic_filter" {
  description = "MQTT topic filter for OwnTracks payloads."
  type        = string
  default     = "owntracks/#"
}

variable "queue_arn" {
  description = "Target SQS queue ARN."
  type        = string
}

variable "queue_url" {
  description = "Target SQS queue URL."
  type        = string
}

variable "create_certificate" {
  description = "Create certificate/key pair and attach the IoT device policy."
  type        = bool
  default     = false
}

locals {
  topic_resource_suffix = replace(replace(var.topic_filter, "#", "*"), "+", "*")
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "iot_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["iot.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iot_rule" {
  name               = var.topic_rule_role
  assume_role_policy = data.aws_iam_policy_document.iot_assume_role.json
}

data "aws_iam_policy_document" "iot_to_sqs" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage"
    ]
    resources = [var.queue_arn]
  }
}

resource "aws_iam_role_policy" "iot_to_sqs" {
  name   = "${var.topic_rule_name}-sqs-send"
  role   = aws_iam_role.iot_rule.id
  policy = data.aws_iam_policy_document.iot_to_sqs.json
}

resource "aws_iot_topic_rule" "owntracks_to_sqs" {
  name        = var.topic_rule_name
  description = "Forward OwnTracks MQTT payloads to SQS."
  enabled     = true
  sql         = "SELECT * FROM '${var.topic_filter}'"
  sql_version = "2016-03-23"

  sqs {
    queue_url  = var.queue_url
    role_arn   = aws_iam_role.iot_rule.arn
    use_base64 = false
  }
}

resource "aws_iot_policy" "device" {
  name = var.device_policy_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Connect"
        Effect   = "Allow"
        Action   = ["iot:Connect"]
        Resource = ["arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:client/*"]
      },
      {
        Sid    = "PublishOwnTracks"
        Effect = "Allow"
        Action = [
          "iot:Publish"
        ]
        Resource = ["arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/${local.topic_resource_suffix}"]
      },
      {
        Sid    = "SubscribeOwnTracks"
        Effect = "Allow"
        Action = [
          "iot:Subscribe"
        ]
        Resource = ["arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topicfilter/${local.topic_resource_suffix}"]
      },
      {
        Sid    = "ReceiveOwnTracks"
        Effect = "Allow"
        Action = [
          "iot:Receive"
        ]
        Resource = ["arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/${local.topic_resource_suffix}"]
      }
    ]
  })
}

resource "aws_iot_certificate" "device" {
  count  = var.create_certificate ? 1 : 0
  active = true
}

resource "aws_iot_policy_attachment" "device" {
  count  = var.create_certificate ? 1 : 0
  policy = aws_iot_policy.device.name
  target = aws_iot_certificate.device[0].arn
}

data "aws_iot_endpoint" "this" {
  endpoint_type = "iot:Data-ATS"
}

output "iot_endpoint" {
  description = "AWS IoT Core endpoint for MQTT clients."
  value       = data.aws_iot_endpoint.this.endpoint_address
}

output "topic_rule_name" {
  description = "IoT topic rule name forwarding messages to SQS."
  value       = aws_iot_topic_rule.owntracks_to_sqs.name
}

output "device_policy_name" {
  description = "IoT policy name for device MQTT permissions."
  value       = aws_iot_policy.device.name
}

output "certificate_arn" {
  description = "Created IoT certificate ARN when enabled."
  value       = var.create_certificate ? aws_iot_certificate.device[0].arn : null
}

output "certificate_pem" {
  description = "Created certificate PEM when create_certificate is enabled."
  value       = var.create_certificate ? aws_iot_certificate.device[0].certificate_pem : null
  sensitive   = true
}

output "certificate_private_key" {
  description = "Created private key when create_certificate is enabled."
  value       = var.create_certificate ? aws_iot_certificate.device[0].private_key : null
  sensitive   = true
}

output "certificate_public_key" {
  description = "Created public key when create_certificate is enabled."
  value       = var.create_certificate ? aws_iot_certificate.device[0].public_key : null
}

output "manual_certificate_instructions" {
  description = "Manual certificate setup steps when certificate auto-generation is disabled."
  value       = var.create_certificate ? null : <<-EOT
In AWS IoT Core console (${data.aws_region.current.name}):
1. Go to Security > Certificates and choose Create certificate.
2. Activate the certificate and download certificate PEM, private key, and Amazon Root CA.
3. Attach policy '${aws_iot_policy.device.name}' to the certificate.
4. Configure your client with MQTT over TLS (port 8883), topic '${var.topic_filter}' (example: owntracks/<user>/<device>), and these required permissions:
   - iot:Connect
   - iot:Publish
   - iot:Subscribe
   - iot:Receive
EOT
}
