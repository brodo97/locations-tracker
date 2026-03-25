# Location Tracker

This repository provisions a modular AWS geolocation platform based on Terraform.

The ingestion pipeline remains unchanged and now lives in an isolated **core** stack:

```text
API Gateway -> SQS -> Lambda -> S3 (JSONL by day)
```

Addons are deployed independently and consume core outputs via `terraform_remote_state`.

## Repository Layout

```text
.
├── core/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── locals.tf
│   ├── provider.tf
│   ├── backend.tf
│   └── modules/
│       ├── api_gateway/
│       ├── lambda/
│       ├── s3/
│       └── sqs/
├── addons/
│   ├── athena/
│   │   ├── athena.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── provider.tf
│   │   └── backend.tf
└── README.md
```

## Core Stack (Unchanged Ingestion)

The `core` stack keeps the original ingestion behavior intact.

### Core outputs for addons

- `data_lake_bucket`
- `data_lake_prefix`
- `aws_region`
- `api_gateway_invoke_url`

## Addon: Athena

The `addons/athena` stack creates:

- Athena database
- Glue external table backed by JSONL in core S3 data lake
- Athena workgroup

### Athena table details

- JSON SerDe: `org.openx.data.jsonserde.JsonSerDe`
- Partitions: `year`, `month`, `day`
- Partition projection enabled (no `MSCK REPAIR TABLE` required)

Outputs:

- `athena_database_name`
- `athena_table_name`
- `athena_workgroup_name`

## Deployment Model (Independent States)

Each stack has its own `backend.tf` and can be deployed independently.

Run in this order:

```bash
cd core
terraform init
terraform apply

cd ../addons/athena
terraform init
terraform apply
```

## Remote State Wiring

All addons read **core** values through `terraform_remote_state`.

- `addons/athena` -> reads core state

If your backend settings differ from defaults, override remote state variables:

- `core_state_backend`
- `core_state_config`
- `query_api_state_backend`
- `query_api_state_config`