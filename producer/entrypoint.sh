#!/bin/bash
set -e

echo "=== PRODUCER START ==="
echo "TPS=$TPS"
echo "DATASET=$DATASET"
echo "S3_ENDPOINT=$S3_ENDPOINT"

python /app/producer.py