import os
import time
import json
import logging
import pandas as pd
from kafka import KafkaProducer

# ---------------- LOGGING ----------------
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("producer")

# ---------------- CONFIG ----------------
KAFKA = os.getenv("KAFKA_BOOTSTRAP", "kafka-service:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "input")

DATASET = os.getenv("DATASET", "a.csv")
S3_PATH = f"s3://datasets/{DATASET}"

TPS = int(os.getenv("TPS", "10"))

# S3 config
S3_ENDPOINT = os.getenv("S3_ENDPOINT", "http://minio:9000")
AWS_KEY = os.getenv("AWS_ACCESS_KEY_ID", "minio")
AWS_SECRET = os.getenv("AWS_SECRET_ACCESS_KEY", "minio123")

storage_options = {
    "key": AWS_KEY,
    "secret": AWS_SECRET,
    "client_kwargs": {
        "endpoint_url": S3_ENDPOINT,
        "verify": False
    }
}

# ---------------- VALIDATION ----------------
TPS = max(1, min(1000, TPS))

logger.info(f"[INIT] dataset={DATASET} TPS={TPS}")

# ---------------- LOAD DATA ----------------
df = pd.read_csv(S3_PATH, storage_options=storage_options)

if "fraud" not in df.columns:
    raise ValueError("Column fraud not found")

# ❗ УДАЛЯЕМ TARGET
df = df.drop(columns=["fraud"])

# удаляем нечисловые как в trainer
for col in ["transaction_id", "timestamp"]:
    if col in df.columns:
        df = df.drop(columns=[col])

for col in df.columns:
    if df[col].dtype == "object":
        df = df.drop(columns=[col])

df = df.fillna(0)

size = len(df)

logger.info(f"[LOAD DONE] rows={size}, features={list(df.columns)}")

# ---------------- KAFKA ----------------
producer = KafkaProducer(
    bootstrap_servers=KAFKA,
    value_serializer=lambda v: json.dumps(v).encode("utf-8")
)

# ---------------- LOOP ----------------
idx = 0
sent = 0
start = time.time()

logger.info("[START] streaming")

while True:
    row = df.iloc[idx].to_dict()

    producer.send(TOPIC, row)

    idx += 1
    sent += 1

    if idx >= size:
        logger.info("[ROTATION] dataset restarted")
        idx = 0

    if sent % TPS == 0:
        elapsed = time.time() - start
        logger.info(f"[STATS] sent={sent} elapsed={round(elapsed,2)}s")

    time.sleep(1 / TPS)