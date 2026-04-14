# 1️⃣ Stage с kaniko
FROM gcr.io/kaniko-project/executor:v1.24.0 AS kaniko

# 2️⃣ Основной образ
FROM python:3.11.4-slim-bookworm

WORKDIR /app

# minimum
RUN apt-get update && apt-get install -y \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# python deps
COPY requirements.txt .
#RUN pip install --no-cache-dir -r requirements.txt
#RUN pip install --no-cache-dir --default-timeout=200 -r requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip pip install --default-timeout=200 -r requirements.txt

# code
COPY train.py .
COPY scripts/ scripts/
RUN chmod +x scripts/*.sh

# 👉 ВАЖНО: добавляем consumer внутрь образа
COPY consumer /opt/consumer

# 3️⃣ Kaniko binaries
COPY --from=kaniko /kaniko /kaniko

# env
ENV PATH="/kaniko:${PATH}"
ENV DOCKER_CONFIG=/kaniko/.docker/
ENV PYTHONPATH="/app"

ENTRYPOINT ["bash", "/app/scripts/entrypoint-kaniko.sh"]
