#!/bin/bash
export GIT_PYTHON_REFRESH=quiet

set -euo pipefail

echo "PWD=$(pwd)"
ls -la /app

echo "=== MODEL TRAINING STARTED ==="

# Очищаем содержимое workspace, но не удаляем саму точку монтирования
if [ -d "/app/workspace" ]; then
    echo "Cleaning /app/workspace contents..."
    rm -rf /app/workspace/*
else
    echo "Creating /app/workspace..."
    mkdir -p /app/workspace
fi

echo "Training model..."

python /app/train.py \
  --input "${TRAIN_DATA_PATH:-s3://datasets/reference.csv}" \
  --output /app/workspace/model.joblib \
  --tracking-uri "${MLFLOW_TRACKING_URI:?}" \
  --experiment-name "${EXPERIMENT_NAME:?}" \
  --auto-register

echo "=== MODEL TRAINING FINISHED ==="

ls -la /app/workspace

echo "=== GET MODEL VERSION ==="

MODEL_VERSION=$(python - <<EOF
import mlflow
from mlflow.tracking import MlflowClient

mlflow.set_tracking_uri("${MLFLOW_TRACKING_URI}")

client = MlflowClient()
v = client.get_latest_versions("${EXPERIMENT_NAME}")[0].version
print(v)
EOF
)

echo "Model version: ${MODEL_VERSION}"

echo "=== GET DATASET FROM MLFLOW ==="

DATASET=$(python - <<EOF
import mlflow
from mlflow.tracking import MlflowClient

mlflow.set_tracking_uri("${MLFLOW_TRACKING_URI}")

client = MlflowClient()
exp = client.get_experiment_by_name("${EXPERIMENT_NAME}")

run = client.search_runs(
    experiment_ids=[exp.experiment_id],
    max_results=1,
    order_by=["start_time DESC"]
)[0]

print(run.data.tags.get("reference_dataset", "unknown"))
EOF
)

echo "Dataset from MLflow: ${DATASET}"

echo "=== XCOM ==="

mkdir -p /airflow/xcom || true
echo "{\"model_version\": \"$MODEL_VERSION\"}" > /airflow/xcom/return.json || true

echo "=== XCOM POPULATED ==="

echo "=== PREPARE BUILD CONTEXT ==="

cp /opt/consumer/requirements.txt /app/workspace/
cp /opt/consumer/Dockerfile /app/workspace/
cp /opt/consumer/consumer.py /app/workspace/
cp /opt/consumer/entrypoint.sh /app/workspace/
cp -r /opt/consumer/datasets /app/workspace/

echo "=== WORKSPACE CONTENT ==="
ls -la /app/workspace

echo "=== CREATE DOCKER CONFIG IN WRITABLE LOCATION ==="

mkdir -p /kaniko/.docker
cp /opt/consumer/config.json /kaniko/.docker/

echo "Docker config created at /kaniko/.docker/config.json"
#ls -la /kaniko/.docker/
#cat /kaniko/.docker/config.json
#ls -la /kaniko/executor || true
echo "DATASET='$DATASET'"

echo "=== BUILD & PUSH IMAGE ==="

export DOCKER_CONFIG=/kaniko/.docker

echo "DATASET='$DATASET'"

/kaniko/executor version

/kaniko/executor \
  --dockerfile=/app/workspace/Dockerfile \
  --context=dir:///app/workspace \
  --build-arg "DATASET=${DATASET}" \
  --destination=index.docker.io/petrakimovdocker/consumer:v${MODEL_VERSION} \
  --destination=index.docker.io/petrakimovdocker/consumer:latest \
  --cache=false --cleanup

echo "=== BUILD & PUSH COMPLETED ==="


#ls -la /kaniko/executor || true

#echo "Mock build: /kaniko/executor with args ..."

#/kaniko/executor --dockerfile=/app/workspace/Dockerfile --context=dir:///app/workspace --build-arg "DATASET=${DATASET}" --destination=index.docker.io/petrakimovdocker/consumer:v${MODEL_VERSION} --destination=index.docker.io/petrakimovdocker/consumer:latest --cache=false --cleanup

#exec /kaniko/executor \
#  --dockerfile=/app/workspace/Dockerfile \
#  --context=dir:///app/workspace \
#  --build-arg "DATASET=${DATASET}" \
#  --destination=index.docker.io/petrakimovdocker/consumer:v${MODEL_VERSION} \
#  --destination=index.docker.io/petrakimovdocker/consumer:latest \
#  --cache=false --cleanup

#/kaniko/executor \
#  --dockerfile=/app/workspace/Dockerfile \
#  --context=dir:///app/workspace \
#  --build-arg DATASET=${DATASET} \  
#  --destination=index.docker.io/petrakimovdocker/consumer:v${MODEL_VERSION} \
#  --destination=index.docker.io/petrakimovdocker/consumer:latest \
#  --cache=false --cleanup 


echo "=== BUILD & PUSH COMPLETED ==="

echo "PATH = $PATH"

echo "=== DONE ==="
