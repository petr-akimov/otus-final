FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends libgomp1 && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
#RUN pip install --no-cache-dir -r requirements.txt

RUN pip install --default-timeout=200 --user --no-cache-dir --upgrade --force-reinstall -r requirements.txt

COPY consumer.py .
COPY model.joblib .

ARG DATASET
ENV DATASET=$DATASET

ENV PYTHONPATH="/app"

CMD ["python", "consumer.py"]