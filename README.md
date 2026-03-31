# Location Tracker

Terraform repository to ingest mobile geolocation telemetry on AWS and query it with Athena

This repository defines an AWS-based infrastructure for ingesting mobile geolocation telemetry and querying it using Amazon Athena.

This branch is specifically designed to integrate with a custom block from my Automate flow:
https://llamalab.com/automate/community/flows/52485

Whenever Automate detects a change in physical activity, it sends an HTTP request to an API Gateway endpoint, enabling real-time ingestion of activity-aware location data.

## Overview

The platform is organized into independent stacks:

- `core`: ingestion pipeline (API Gateway, SQS, Lambda, S3).
- `addons/athena`: analytics layer over core data stored in S3.

Main data flow:

```text
Client/Automate -> API Gateway -> SQS -> Lambda -> S3
```

## What This Branch Adds (Automate Integration)

Compared to the main baseline, this branch extends ingestion with:

- Event type `_type = "activity"` accepted by API validation.
- Dual S3 sink managed by Lambda:
- `location` events -> location bucket -> `locations.jsonl`
- `activity` events -> activity bucket -> `activities.jsonl`
- Optional API Gateway logging (`api_gateway_enable_logging`) with:
- access logs
- execution logs
- CloudWatch metrics at stage level

The existing `location` ingestion path remains unchanged.

## How It Works

1. The client (for example Llamalab Automate) sends JSON payloads to `POST /locations`.
2. API Gateway validates the payload against an OwnTracks-compatible schema and forwards it to SQS.
3. Lambda processes SQS messages and routes data based on `_type`:
- `location` -> location bucket
- `activity` -> activity bucket
4. Objects are appended as JSONL files partitioned by UTC date:

```text
year=YYYY/month=MM/day=DD/locations.jsonl
year=YYYY/month=MM/day=DD/activities.jsonl
```

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
│   ├── terraform.tfvars
│   ├── variables.tf
│   └── modules/
│       ├── api_gateway/
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
- IAM permissions for API Gateway, SQS, Lambda, S3, Athena, Glue, IAM, CloudWatch Logs

## Configuration

### 1) Terraform Backend

Each stack uses a separate Terraform state.

- Copy `backend.tf.example` to `backend.tf` in each stack, or edit existing backend files.
- Configure backend S3 bucket, key, and region.

### 2) Core Variables

Set at least these values in `core/terraform.tfvars` (or via CLI/CI vars):

- `project_name`
- `environment`
- `api_gateway_enable_logging` (`true` or `false`)

Optional but relevant in this branch:

- `activity_project_name` (default: `activities-tracker`)
- `s3_lifecycle_days`
- `lambda_*` and `sqs_*` tuning variables

### 3) Athena Addon Variables

In `addons/athena/terraform.tfvars`:

- `project_name`
- `environment`

For remote state wiring, verify in `addons/athena/variables.tf`:

- `core_state_backend`
- `core_state_config`

## Deployment

Deploy stacks in this order.

### Core

```bash
cd core
terraform init
terraform plan
terraform apply
```

Useful outputs:

- `api_gateway_invoke_url`
- `data_lake_bucket`
- `data_lake_prefix`
- `aws_region`

### Athena Addon

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

## Usage

### Send Data to the API

Use `api_gateway_invoke_url` with path `/locations`.

Location event example:

```bash
curl -X POST "<api_gateway_invoke_url>/locations" \
	-H "Content-Type: application/json" \
	-d '{"_type":"location","lat":45.46,"lon":9.19,"tst":1774915200}'
```

Activity event example:

```bash
curl -X POST "<api_gateway_invoke_url>/locations" \
	-H "Content-Type: application/json" \
	-d '{"_type":"activity","tst":1774915300,"act":3,"_id":"phone-01"}'
```

API returns an acknowledgment payload with a queue `message_id`.

### Query Data with Athena

The current Athena addon creates a table for location data with partition projection (`year`, `month`, `day`).

Example query:

```sql
SELECT lat, lon, tst
FROM locations
WHERE year = '2026' AND month = '03' AND day = '25'
ORDER BY tst DESC
LIMIT 100;
```

## Created Resources

### Core

- API Gateway REST API with `POST /locations` endpoint
- SQS queue
- Python 3.13 Lambda processor with SQS trigger
- Location S3 bucket (versioning + SSE AES256 + optional lifecycle)
- Activity S3 bucket (versioning + SSE AES256 + optional lifecycle)
- Optional API Gateway CloudWatch logging resources

### Athena Addon

- Athena database
- Athena workgroup
- Glue external table for partitioned location JSONL data

## Operational Notes

- Supported ingestion event types in Lambda: `location`, `activity`.
- Other `_type` values are ignored by Lambda.
- File partitioning uses UTC timestamp (`tst`), fallback to current time when missing.
- Current Athena addon models location data; activity analytics can be added with an additional table if needed.