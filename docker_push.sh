#!/bin/bash

# Скрипт: retry_on_timeout.sh
# Использование: ./retry_on_timeout.sh docker push petrakimovdocker/trainer:latest

COMMAND="$@"

if [ -z "$COMMAND" ]; then
    echo "Ошибка: не указана команда."
    echo "Пример: $0 docker push petrakimovdocker/trainer:latest"
    exit 1
fi

while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Выполняется: $COMMAND"
    OUTPUT=$($COMMAND 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo "✅ Команда выполнена успешно. Выход."
        exit 0
    else
        # Проверяем наличие специфической ошибки TLS handshake timeout
        if echo "$OUTPUT" | grep -q "TLS handshake timeout"; then
            echo "⚠️  Обнаружен TLS handshake timeout. Повтор через 10 секунд..."
            sleep 10
            continue
        else
            echo "❌ Команда завершилась с невосстанавливаемой ошибкой (код $EXIT_CODE). Вывод:"
            echo "$OUTPUT"
            exit $EXIT_CODE
        fi
    fi
done