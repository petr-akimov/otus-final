#!/bin/bash

set -e

LOG=/home/ubuntu/user_data_execution.log

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG
}

log "Starting bootstrap"

export HOME=/home/ubuntu

apt-get update

log "Installing packages"

apt-get install -y \
    python3-pip \
    git \
    s3cmd \
    build-essential

pip3 install \
    pandas \
    pyarrow \
    scikit-learn \
    joblib \
    lightgbm

log "Configuring s3cmd"

cat <<EOF > /home/ubuntu/.s3cfg
[default]
access_key = ${access_key}
secret_key = ${secret_key}
host_base = storage.yandexcloud.net
host_bucket = %(bucket)s.storage.yandexcloud.net
use_https = True
EOF

chown ubuntu:ubuntu /home/ubuntu/.s3cfg
chmod 600 /home/ubuntu/.s3cfg

TARGET_BUCKET=${s3_bucket}

WORKDIR=/home/ubuntu/ml
mkdir -p $WORKDIR
cd $WORKDIR


log "Waiting for ETL scripts"

while [ ! -f etl.py ]; do
  sleep 2
done

while [ ! -f train_local.py ]; do
  sleep 2
done


log "Downloading dataset"

FILE_NAME="2022-11-04.txt"

s3cmd get \
  s3://otus-mlops-source-data/$FILE_NAME \
  data.txt

log "Running ETL"

python3 etl.py \
  --input data.txt \
  --output parquet


log "Uploading parquet files to S3"

for f in parquet/*.parquet
do
    s3cmd put $f s3://$TARGET_BUCKET/parquet/
done


log "Training model"

python3 train_local.py \
  --input parquet \
  --output model.joblib


#log "Uploading model to S3"

#s3cmd put model.joblib s3://$TARGET_BUCKET/model/


log "Bootstrap completed"
