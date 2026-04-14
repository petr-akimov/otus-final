import os
import json
import logging
import joblib
import pandas as pd
import requests
import psutil
import time  # ✅ NEW

from kafka import KafkaConsumer, KafkaProducer, TopicPartition  # ✅ UPDATED
from requests.auth import HTTPBasicAuth

from prometheus_client import start_http_server, Counter, Gauge, Histogram

from evidently import ColumnMapping
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset

import redis

# ---------------- LOGGING ----------------
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("consumer")

# ---------------- CONFIG ----------------
KAFKA = os.getenv("KAFKA_BOOTSTRAP", "kafka:9092")

INPUT_TOPIC = os.getenv("KAFKA_INPUT_TOPIC", "input")
OUTPUT_TOPIC = os.getenv("KAFKA_OUTPUT_TOPIC", "predictions")

DATASET = os.getenv("DATASET", "a.csv")
S3_PATH = f"s3://datasets/{DATASET}"

AIRFLOW_API = os.getenv("AIRFLOW_API")

DRIFT_THRESHOLD = float(os.getenv("DRIFT_THRESHOLD", "0.5"))
BUFFER_SIZE = 500

MODEL_PATH = "model.joblib"

# ---------------- REDIS ----------------
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_KEY = "drift_detected"

redis_client = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    decode_responses=True
)

# ---------------- S3 ----------------
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

logger.info(f"[INIT] dataset={DATASET}")

# ---------------- PROMETHEUS ----------------
PREDICTIONS = Counter("predictions_total", "Total predictions")
FRAUD_PREDICTIONS = Counter("fraud_predictions_total", "Fraud predictions")
DRIFT_EVENTS = Counter("drift_events_total", "Drift detections")

CPU_USAGE = Gauge("cpu_usage_percent", "CPU usage percent")
MEMORY_USAGE = Gauge("memory_usage_bytes", "Memory usage bytes")
MEMORY_USAGE_PERCENT = Gauge("memory_usage_percent", "Memory usage percent")

DRIFT_STATE = Gauge("dataset_drift", "Dataset drift detected (1=True, 0=False)")

PIPELINE_LATENCY = Histogram(
    "pipeline_latency_seconds",
    "Full pipeline latency: consume → predict → produce"
)

# ✅ NEW ---------------- KAFKA LAG METRICS ----------------
KAFKA_LAG = Gauge("kafka_consumer_lag", "Kafka consumer lag", ["topic", "partition"])
KAFKA_CURRENT_OFFSET = Gauge("kafka_current_offset", "Current consumer offset", ["topic", "partition"])
KAFKA_END_OFFSET = Gauge("kafka_end_offset", "Latest offset in topic", ["topic", "partition"])

start_http_server(8000)

# ---------------- LOAD MODEL ----------------
model = joblib.load(MODEL_PATH)
logger.info("[MODEL] loaded")

# ---------------- LOAD REFERENCE ----------------
def load_reference():
    try:
        df = pd.read_csv(S3_PATH, storage_options=storage_options)
        logger.info(f"[REFERENCE] loaded: {df.shape}")

        if "fraud" in df.columns:
            df = df.drop(columns=["fraud"])

        for col in ["transaction_id", "timestamp"]:
            if col in df.columns:
                df = df.drop(columns=[col])

        df = df.fillna(0)

        return df

    except Exception as e:
        logger.error(f"[REFERENCE ERROR] {e}")
        return None


reference_df = load_reference()

# ---------------- KAFKA ----------------
consumer = KafkaConsumer(
    INPUT_TOPIC,
    bootstrap_servers=KAFKA,
    group_id="consumer-group",
    value_deserializer=lambda x: json.loads(x.decode("utf-8")),
    auto_offset_reset="latest",
    enable_auto_commit=True
)

producer = KafkaProducer(
    bootstrap_servers=KAFKA,
    value_serializer=lambda x: json.dumps(x).encode("utf-8")
)

# ✅ NEW ---------------- KAFKA LAG FUNCTION ----------------
def update_kafka_lag():
    """
    Считает lag = end_offset - current_offset
    и публикует в Prometheus
    """
    try:
        partitions = consumer.assignment()

        if not partitions:
            return

        end_offsets = consumer.end_offsets(partitions)

        for tp in partitions:
            current_offset = consumer.position(tp)
            end_offset = end_offsets.get(tp, 0)

            lag = end_offset - current_offset

            KAFKA_LAG.labels(
                topic=tp.topic,
                partition=str(tp.partition)
            ).set(lag)

            KAFKA_CURRENT_OFFSET.labels(
                topic=tp.topic,
                partition=str(tp.partition)
            ).set(current_offset)

            KAFKA_END_OFFSET.labels(
                topic=tp.topic,
                partition=str(tp.partition)
            ).set(end_offset)

    except Exception as e:
        logger.error(f"[KAFKA LAG ERROR] {e}")

# ---------------- DRIFT ----------------
def detect_drift(current_df: pd.DataFrame):
    if reference_df is None:
        return False

    try:
        column_mapping = ColumnMapping()
        column_mapping.numerical_features = list(reference_df.columns)

        report = Report(metrics=[DataDriftPreset()])

        report.run(
            reference_data=reference_df,
            current_data=current_df,
            column_mapping=column_mapping
        )

        result = report.as_dict()
        drift = result["metrics"][0]["result"]["dataset_drift"]

        logger.info(f"[DRIFT] dataset_drift={drift}")

        return drift

    except Exception as e:
        logger.error(f"[DRIFT ERROR] {e}")
        return False


# ---------------- AIRFLOW ----------------
def trigger_dag():
    if not AIRFLOW_API:
        return

    try:
        payload = {"conf": {"drift_dataset": DATASET}}

        logger.info(f"[AIRFLOW] trigger with dataset={DATASET}")

        r = requests.post(
            AIRFLOW_API,
            json=payload,
            auth=HTTPBasicAuth("admin", "admin"),
            timeout=5
        )

        logger.info(f"[AIRFLOW] {r.status_code} {r.text}")

    except Exception as e:
        logger.error(f"[AIRFLOW ERROR] {e}")


# ---------------- LOOP ----------------
buffer = []

logger.info("[START] consuming")

for msg in consumer:
    try:
        start_time = time.time()

        data = msg.value
        df = pd.DataFrame([data])

        # ---------------- PREDICT ----------------
        pred = model.predict(df)[0]
        proba = model.predict_proba(df)[0][1]

        producer.send(OUTPUT_TOPIC, {
            "prediction": int(pred),
            "probability": float(proba)
        })

        # ---------------- METRICS ----------------
        PREDICTIONS.inc()

        if pred == 1:
            FRAUD_PREDICTIONS.inc()

        CPU_USAGE.set(psutil.cpu_percent())
        MEMORY_USAGE.set(psutil.virtual_memory().used)
        MEMORY_USAGE_PERCENT.set(psutil.virtual_memory().percent)

        # ✅ NEW: Kafka lag update
        update_kafka_lag()

        # ---------------- DRIFT ----------------
        buffer.append(data)

        if len(buffer) >= BUFFER_SIZE:
            df_buffer = pd.DataFrame(buffer).fillna(0)

            drift_detected = detect_drift(df_buffer)

            DRIFT_STATE.set(1 if drift_detected else 0)

            if drift_detected:
                DRIFT_EVENTS.inc()

                is_set = redis_client.set(REDIS_KEY, "1", nx=True)

                if is_set:
                    logger.info("[REDIS] drift detected → trigger DAG")
                    trigger_dag()
                else:
                    logger.info("[REDIS] drift already active → skip")
            else:
                if redis_client.exists(REDIS_KEY):
                    redis_client.delete(REDIS_KEY)
                    logger.info("[REDIS] drift resolved")

            buffer.clear()

        PIPELINE_LATENCY.observe(time.time() - start_time)

    except Exception as e:
        logger.error(f"[ERROR] {e}")
        continue
