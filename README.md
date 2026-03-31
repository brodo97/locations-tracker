# Location Tracker

**Terraform repository to ingest mobile geolocation telemetry on AWS and query it with Athena**

This repository defines an AWS-based infrastructure for ingesting mobile geolocation telemetry and querying it using Amazon Athena.

If you want to dynamically adjust OwnTracks’ recording mode based on device activity, check out my Automate flow:
[https://llamalab.com/automate/community/flows/52485](https://llamalab.com/automate/community/flows/52485)

To enable ingestion of activity data, use the `automate` branch of this repository.

## Overview

The platform is organized into independent stacks:

- `core`: data ingestion pipeline.
- `addons/athena`: analytics layer on top of the core data lake.

Main data flow:

```text
Client HTTP -> API Gateway -> SQS -> Lambda -> S3 (JSONL partizionato per data)
```

## How It Works

1. The client sends JSON payloads to the API Gateway endpoint `POST /locations`.
2. API Gateway validates the request body and forwards the message to SQS.
3. Lambda reads messages from SQS, keeps only events with `_type = "location"`, and writes them to S3.
4. Files are stored in JSON Lines format using the following path pattern:

```text
year=YYYY/month=MM/day=DD/locations.jsonl
```

5. The Athena addon reads the core Terraform state, then creates a database/workgroup and an external Glue table on top of the S3 layout.

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

## Prerequisiti

- Terraform >= 1.6.0
- AWS credentials configured locally
- IAM permissions to create API Gateway, SQS, Lambda, S3, Athena, Glue, and IAM resources

## Configuration

### 1) Terraform Backend

Each stack uses a separate Terraform state.

- Copy `backend.tf.example` to `backend.tf` in each stack (`core` and `addons/athena`), or edit the existing backend files.
- Set S3 backend bucket, key, and region values. (optional)

### 2) Main Variables

In `core/terraform.tfvars`:

- `project_name`
- `environment`

In `addons/athena/terraform.tfvars`:

- `project_name`
- `environment`

To connect Athena to core through remote state, verify in `addons/athena/variables.tf`:

- `core_state_backend`
- `core_state_config`

## Deploy

Run the stacks in this order.

### Core

```bash
cd core
terraform init
terraform plan
terraform apply
```

Output utile:

Useful outputs:

- `api_gateway_invoke_url`
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

Output utile:

Useful outputs:

- `athena_database_name`
- `athena_table_name`
- `athena_workgroup_name`

## Usage

### Sending Data to the API

Use the `api_gateway_invoke_url` output with the `/locations` path.

Example:

```bash
curl -X POST "<api_gateway_invoke_url>/locations" \
	-H "Content-Type: application/json" \
	-d '{"_type":"location","lat":45.46,"lon":9.19,"tst":1774915200}'
```

The API response includes an acknowledgment containing the queue `message_id`.

### Querying Data with Athena

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

- API Gateway REST API with `POST /locations` endpoint
- SQS queue
- Python 3.13 Lambda function with SQS trigger
- Versioned S3 bucket with server-side encryption (AES256)

### Athena Addon

- Athena database
- Athena workgroup
- External Glue Catalog table on partitioned JSONL data

## Operational Notes

- Lambda writes only events with `_type = "location"`.
- Data lake files are appended to `locations.jsonl` for each UTC day.
- Naming and tagging are driven by `project_name`, `environment`, and `additional_tags`.
