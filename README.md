# Location Tracker

This repository provisions a production-ready, modular AWS data ingestion pipeline for geolocation payloads. It is designed to receive payloads from the popular OwnTracks app ([https://owntracks.org/](https://owntracks.org/)).

## What It Does

The pipeline accepts HTTP JSON payloads from OwnTracks, queues them, processes them in batches, and writes them to S3 as JSON Lines (JSONL) partitioned by date.

### Example Payload

```json
{
  "_type": "location",
  "lat": 44.000000,
  "lon": 11.000000,
  "tst": 1773278468,
  "batt": 88,
  "vel": 0
}
```

## Architecture

```text
API Gateway -> SQS -> Lambda -> S3
```

1. **API Gateway** receives HTTP requests with JSON payloads
2. **SQS** buffers incoming messages
3. **Lambda** is triggered by SQS in batches
4. **Lambda → S3** appends JSONL records by day

## S3 Layout

```text
s3://<project>-<environment>/
  year=YYYY/
    month=MM/
      day=DD/
        locations.jsonl
```

## Key Behaviors

* **Batching:** Lambda reads messages in batches and groups by day
* **Partitioning:** Files are written to `year=YYYY/month=MM/day=DD/locations.jsonl`
* **Appending:** Lambda reads existing JSONL, appends new lines, writes back
* **Versioning & Encryption:** S3 has versioning and SSE enabled
* **Lifecycle:** Keeps only the latest 3 noncurrent versions; optional expiration for current objects

## Modules

* `modules/api_gateway`: REST API + SQS integration
* `modules/sqs`: SQS queue with delivery delay and long polling
* `modules/lambda`: Lambda + IAM + SQS trigger
* `modules/s3`: S3 bucket + encryption + versioning + lifecycle

## Naming Convention

All resource names are derived from:

```text
<project_name>-<environment>-<resource-type>
```

Examples:

* S3 bucket: `untrucks-prod-locations`
* SQS queue: `untrucks-prod-locations-queue`
* Lambda: `untrucks-prod-processor`
* API Gateway: `untrucks-prod-api`

The logic is centralized in `locals.tf`.

## Configuration

All values are configurable via variables or `locals.tf`. Common ones:

* `project_name`
* `environment`
* `aws_region`
* `lambda_timeout_seconds`
* `lambda_batch_window_seconds`
* `sqs_delivery_delay_seconds`
* `sqs_receive_wait_time_seconds`
* `s3_lifecycle_days`

### Notes

* `backend.tf` is intentionally ignored by Git to avoid exposing backend details

## How To Use

### 1. Initialize Backend

Create your S3 bucket and optional DynamoDB lock table, then configure `backend.tf` or pass values via `-backend-config`.

### 2. Deploy

```bash
terraform init
terraform plan
terraform apply
```

## Outputs

* **API Gateway Invoke URL**: Base URL for ingesting payloads
* **SQS Queue URL**: Where API Gateway sends messages
* **S3 Bucket Name**: Storage target for JSONL

## API Response

The API returns a JSON acknowledgement from the SQS response:

```json
{
  "_type": "location_ack",
  "message_id": "<sqs-message-id>"
}
```

## Security & Permissions

* Lambda has least-privilege access to SQS and S3
* API Gateway assumes an IAM role that can only `sqs:SendMessage`

## Project Structure

```text
.
├─ backend.tf
├─ locals.tf
├─ main.tf
├─ outputs.tf
├─ provider.tf
├─ variables.tf
└─ modules/
   ├─ api_gateway/
   ├─ lambda/
   ├─ s3/
   └─ sqs/
```