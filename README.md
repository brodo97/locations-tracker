# Location Tracker

**Terraform repository to ingest mobile geolocation telemetry on AWS and query it with Athena**

This repository defines an AWS-based infrastructure for ingesting mobile geolocation telemetry and querying it using Amazon Athena.

If you want to dynamically adjust OwnTracks recording mode based on device activity, check out my Automate flow:
[https://llamalab.com/automate/community/flows/52485](https://llamalab.com/automate/community/flows/52485)

To enable ingestion of activity data, use the `automate` branch of this repository.

## Overview

The platform is organized into independent stacks:

- `core`: data ingestion pipeline.
- `addons/athena`: analytics layer on top of the core data lake.

Supported ingestion paths in `core`:

```text
HTTP: API Gateway -> SQS -> Lambda -> S3 (JSONL partitioned by date)
MQTT: IoT Core Topic Rule -> SQS -> Lambda -> S3 (JSONL partitioned by date)
```

You can enable either path independently (or both at the same time). Both write to the same SQS queue and the same downstream pipeline.

## How It Works

1. HTTP clients can send JSON payloads to API Gateway `POST /locations` when `enable_api_gateway = true`.
2. MQTT clients can publish to IoT Core topic `owntracks/<user>/<device>` when `enable_iot_core = true`.
3. IoT Core rule subscribes to `owntracks/#` with SQL:

```sql
SELECT * FROM 'owntracks/#'
```

4. Both ingestion methods forward data into the same SQS queue.
5. Lambda reads messages from SQS, keeps only events with `_type = "location"`, and writes them to S3.
6. Files are stored in JSON Lines format using:

```text
year=YYYY/month=MM/day=DD/locations.jsonl
```

7. The Athena addon reads core Terraform state and creates analytics resources on top of this layout.

## Repository Structure

```text
.
├── core/
│   ├── backend.tf
│   ├── backend.tf.example
│   ├── locals.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── validation.tf
│   ├── terraform.tfvars
│   ├── variables.tf
│   └── modules/
│       ├── api_gateway/
│       ├── iot_core/
│       ├── lambda/
│       ├── s3/
│       └── sqs/
└── addons/
    └── athena/
        ├── athena.tf
        ├── backend.tf
        ├── backend.tf.example
        ├── main.tf
        ├── outputs.tf
        ├── provider.tf
        ├── terraform.tfvars
        └── variables.tf
```

## Prerequisites

- Terraform >= 1.6.0
- AWS credentials configured locally
- IAM permissions to create API Gateway, SQS, Lambda, S3, IoT Core, Athena, Glue, and IAM resources

## Configuration

### 1) Terraform Backend

Each stack uses a separate Terraform state.

- Copy `backend.tf.example` to `backend.tf` in each stack (`core` and `addons/athena`), or edit existing backend files.
- Set backend bucket/key/region values.

### 2) Core Variables

Set at least:

- `project_name`
- `environment`

Ingestion toggles and IoT options:

- `enable_api_gateway` (default `true`)
- `enable_iot_core` (default `false`)
- `iot_core_region` (default `null` => uses `aws_region`)
- `iot_create_certificate` (default `false`)
- `iot_topic_filter` (default `owntracks/#`)

Examples in `core/terraform.tfvars`:

HTTP only (default behavior):

```hcl
enable_api_gateway = true
enable_iot_core    = false
```

MQTT only:

```hcl
enable_api_gateway    = false
enable_iot_core       = true
iot_core_region       = "eu-west-1"
iot_create_certificate = true
```

HTTP + MQTT together:

```hcl
enable_api_gateway    = true
enable_iot_core       = true
iot_core_region       = "eu-west-1"
iot_create_certificate = false
```

### 3) IoT Region Fallback

`iot_core_region` is optional. If omitted, IoT Core uses the same region as the core stack (`aws_region`).

This project includes a safety check (`iot_core_unsupported_regions`) to block known unsupported regions (default includes `eu-south-1`). If the check fails, set `iot_core_region` to a supported fallback region (for example `eu-west-1`) and re-run plan/apply.

### 4) Athena Addon Variables

In `addons/athena/terraform.tfvars` set:

- `project_name`
- `environment`

To connect Athena to core through remote state, verify in `addons/athena/variables.tf`:

- `core_state_backend`
- `core_state_config`

## Deploy

Run stacks in this order.

### Core

```bash
cd core
terraform init
terraform plan
terraform apply
```

Useful outputs:

- `api_gateway_invoke_url` (null when HTTP ingestion is disabled)
- `sqs_queue_url`
- `iot_endpoint` (null when IoT ingestion is disabled)
- `owntracks_mqtt_connection` (null when IoT ingestion is disabled)
- `iot_manual_certificate_instructions` (only when IoT is enabled and auto cert is disabled)
- `data_lake_bucket`
- `data_lake_prefix`
- `aws_region`

### Addon Athena

```bash
cd addons/athena
terraform init
terraform plan
terraform apply
```

Useful outputs:

- `athena_database_name`
- `athena_table_name`
- `athena_workgroup_name`

## OwnTracks Configuration

### HTTP Mode (API Gateway)

Use `api_gateway_invoke_url` output with `/locations` path.

Example:

```bash
curl -X POST "<api_gateway_invoke_url>/locations" \
  -H "Content-Type: application/json" \
  -d '{"_type":"location","lat":45.46,"lon":9.19,"tst":1774915200}'
```

### MQTT Mode (IoT Core)

Use the generated `owntracks_mqtt_connection` output:

```text
Host: <iot_endpoint>
Port: 8883
Topic: owntracks/<user>/<device>
```

OwnTracks MQTT requirements:

- TLS enabled
- Client certificate, private key, and Amazon Root CA
- Topic under `owntracks/#`

Certificate options:

1. `iot_create_certificate = true`:
- Terraform creates certificate and policy attachment.
- Retrieve values from outputs (`iot_certificate_pem`, `iot_certificate_private_key`, `iot_certificate_public_key`).

2. `iot_create_certificate = false`:
- Terraform creates only IoT policy.
- Follow output `iot_manual_certificate_instructions` to create/import certificate in AWS console and attach policy.

When `iot_create_certificate = true`, certificate material is stored in Terraform state. Use an encrypted remote backend and restrict state access.

## Querying Data with Athena

The table uses partition projection on `year`, `month`, and `day`, so queries should filter partitions to maximize performance.

Example:

```sql
SELECT lat, lon, tst
FROM locations
WHERE year = '2026' AND month = '03' AND day = '25'
ORDER BY tst DESC
LIMIT 100;
```

## Created Resources

### Core

- SQS queue (shared by HTTP and MQTT ingestion)
- Optional API Gateway REST API with `POST /locations` endpoint
- Optional IoT Core topic rule (`owntracks/#` -> SQS)
- IAM role/policy for IoT Core to send messages to SQS
- Optional IoT certificate and policy attachment
- Python 3.13 Lambda function with SQS trigger
- Versioned S3 bucket with server-side encryption (AES256)

### Athena Addon

- Athena database
- Athena workgroup
- External Glue Catalog table on partitioned JSONL data

## Operational Notes

- Lambda behavior is unchanged and still stores only payloads where `_type = "location"`.
- Data files are appended to `locations.jsonl` for each UTC day.
- Naming and tagging are driven by `project_name`, `environment`, and `additional_tags`.
