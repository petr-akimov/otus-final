# Stage 1: Builder 
#FROM python:3.11.4-slim-bookworm as builder

#WORKDIR /app

#COPY requirements.txt .

#RUN pip install --user --no-cache-dir --upgrade --force-reinstall -r requirements.txt

# Stage 2: Final — минимальный образ с системными библиотеками
#FROM python:3.11.4-slim-bookworm

#WORKDIR /app

#RUN apt-get update && \
#    apt-get install -y --no-install-recommends libgomp1 && \
#    rm -rf /var/lib/apt/lists/*

# Копируем Python-пакеты из builder
#COPY --from=builder /root/.local /root/.local
#ENV PATH=/root/.local/bin:$PATH

# Копируем приложение
#COPY entrypoint.sh .
#COPY consumer.py .
#COPY model.joblib .

#ARG DATASET
#ENV DATASET=$DATASET

#ENV PYTHONPATH="/app"

#ENTRYPOINT ["bash", "/app/entrypoint.sh"]

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