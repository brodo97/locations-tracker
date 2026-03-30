import json
import os
import time
import boto3
from datetime import datetime, timezone
from collections import defaultdict

s3 = boto3.client("s3")
LOCATION_BUCKET = os.environ.get("LOCATION_BUCKET")
ACTIVITY_BUCKET = os.environ.get("ACTIVITY_BUCKET")

SUPPORTED_TYPES = {"location", "activity"}
FILENAME_BY_TYPE = {
    "location": "locations.jsonl",
    "activity": "activities.jsonl"
}


def _bucket_for(record_type):
    if record_type == "location":
        if not LOCATION_BUCKET:
            raise ValueError("LOCATION_BUCKET is not set")
        return LOCATION_BUCKET
    if record_type == "activity":
        if not ACTIVITY_BUCKET:
            raise ValueError("ACTIVITY_BUCKET is not set")
        return ACTIVITY_BUCKET
    return None


def _key_for(record_type, dt):
    return (
        f"year={dt.year}/"
        f"month={dt.month:02d}/"
        f"day={dt.day:02d}/"
        f"{FILENAME_BY_TYPE[record_type]}"
    )


def _append_jsonl(bucket, key, lines):
    new_data = "\n".join(lines) + "\n"

    try:
        obj = s3.get_object(Bucket=bucket, Key=key)
        existing_data = obj["Body"].read().decode("utf-8")
        updated_data = existing_data + new_data

    except s3.exceptions.NoSuchKey:
        updated_data = new_data
    except Exception as e:
        # fallback compatibile
        if "NoSuchKey" in str(e):
            updated_data = new_data
        else:
            raise e

    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=updated_data.encode("utf-8"),
        ContentType="application/json"
    )


def handler(event, context):
    # raggruppiamo per file (giorno)
    batches = defaultdict(list)

    print(f"Processing {len(event['Records'])} records")

    for record in event["Records"]:
        body = json.loads(record["body"])

        record_type = body.get("type")
        if record_type not in SUPPORTED_TYPES:
            print(f"Skipping record with type {record_type}")
            continue

        ts = body.get("tst", int(time.time()))
        dt = datetime.fromtimestamp(ts, tz=timezone.utc)

        bucket = _bucket_for(record_type)
        key = _key_for(record_type, dt)

        batches[(bucket, key)].append(json.dumps(body))

    batch_labels = ",".join([f"{bucket}:{key}" for (bucket, key) in batches.keys()])
    print(f"Prepared {len(batches)} batches: {batch_labels}")

    # scrittura per ogni file
    for (bucket, key), lines in batches.items():
        _append_jsonl(bucket, key, lines)

    return {
        "statusCode": 200,
        "body": json.dumps({"processed": len(event["Records"])})
    }
