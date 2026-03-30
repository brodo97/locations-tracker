import json
import os
import time
import boto3
from datetime import datetime, timezone
from collections import defaultdict

s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET_NAME"]

def handler(event, context):
    # raggruppiamo per file (giorno)
    batches = defaultdict(list)

    print(f"Processing {len(event['Records'])} records")

    for record in event["Records"]:
        body = json.loads(record["body"])

        if body.get("type") != "location":
            print(f"Skipping record with type {body.get('type')}")
            continue

        ts = body.get("tst", int(time.time()))
        dt = datetime.fromtimestamp(ts, tz=timezone.utc)

        key = (
            f"year={dt.year}/"
            f"month={dt.month:02d}/"
            f"day={dt.day:02d}/"
            f"locations.jsonl"
        )

        batches[key].append(json.dumps(body))

    print(f"Prepared {len(batches)} batches: {','.join(batches.keys())}")

    # scrittura per ogni file
    for key, lines in batches.items():
        new_data = "\n".join(lines) + "\n"

        try:
            obj = s3.get_object(Bucket=BUCKET, Key=key)
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
            Bucket=BUCKET,
            Key=key,
            Body=updated_data.encode("utf-8"),
            ContentType="application/json"
        )

    return {
        "statusCode": 200,
        "body": json.dumps({"processed": len(event["Records"])})
    }