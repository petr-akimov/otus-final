### Итоговый проект курса OTUS. 
# Особенности внедрения проекта по определению мошеннических транзакций в двух разных платформах автоматизации Gitlab-CI/CD и GitHub Actions - отличия, преимущества и недостатки

## Описание проекта

Данный проект реализует end-to-end MLOps pipeline для задачи антифрода (поиск мошеннических транзакций) с использованием стриминговой обработки данных, мониторинга дрифта и автоматического переобучения модели.

Система построена на базе Kubernetes (Managed Service for Kubernetes) и покрывает полный жизненный цикл ML-модели:
- ingestion данных
- онлайн-инференс
- мониторинг качества
- детектирование дрифта
- автоматическое переобучение
- деплой новой модели
- ручная настройка интенсивности потока TPS и сдвига данных

---

## Архитектура

### Основные компоненты

- **Kafka** — транспорт данных (input / predictions топики)
- **Producer** — отправка данных из датасета в Kafka
- **Consumer (HPA 4–6 pod)** — онлайн-инференс модели
- **MLflow** — трекинг экспериментов и моделей
- **Airflow** — оркестрация пайплайнов
- **Evidently** — мониторинг дрифта данных
- **MinIO** — S3-совместимое хранилище
- **PostgreSQL** — backend для Airflow
- **HTTP POST-запрос в Airflow** — триггер переобучения
- **HTTP POST-запрос в GitLab** — триггер развертывания модели новой версии
- **GitLab CI/CD** — деплой

---

## Общая схема решения (Gitlab)

<img src="png/fraud_detection_platform_gitlab_ci_managed.png?raw=true" alt="Общая схема" title="Общая схема решения (Gitlab)" width="100%"> <br>

---

## Используемые технологии

| Компонент | Назначение |
|----------|-----------|
| GitLab | CI/CD |
| Yandex Cloud | Облачная среда для развертывания инфраструктуры и приложений |
| Kafka | стриминг данных |
| Airflow | orchestration |
| MLflow | управление моделями |
| Evidently | мониторинг дрифта |
| Docker | контейнеризация |
| PostgreSQL | metadata storage |
| MinIO | хранение данных |
| Python scripts | producer / consumer / watchdog |

---

## Структура репозитория

```bash
.
├── k8s/                # Kubernetes манифесты инфраструктуры
├── dags/               # Airflow DAGs
├── producer/           # исходный код для сборки образа producer 
├── helm/               # Helm-чарты producer/consumer
├── monitoring/         # k8s-манифесты мониторинга
├── png/                # схемы, картинки, оформление
├── tf/                 # terraform-манифесты 
├── trainer/            # исходный код для сборки образа trainer (обучение модели для consumer, A/B-тест, публикация)
└── README.md
```

---

## Поток данных

### 1. Базовый сценарий

- Producer читает `a.csv` из MinIO  
- Отправляет данные в Kafka (`input`)  

**Consumer:**
- читает сообщения  
- делает предсказания  
- пишет результат в `predictions`  

**Evidently:**
- сравнивает поток с референсом (`a.csv`)  
- мониторит drift  

---

### 2. Drift + переобучение

- Пользователь меняет helm/producer/values.yaml:  
  `a.csv → b.csv`  
- Producer начинает отправлять данные (заранее подготовленные, с data drift)   
- Evidently фиксирует **data drift**  
- Триггерится Airflow DAG переобучения  
- Пользователь наблюдает в мониторинге:
    * data drift 0 → 1
- Пользователь получает уведомления в мессенджер Telegram:
    * Drift state change

---

### 3. Пайплайн переобучения (Airflow)

**DAG выполняет:**

- загрузка данных из MinIO  
- обучение модели  
- логирование в MLflow  
- валидация  
- A/B тест  
- выбор champion модели  
- сборка Docker-образа  
- публикация в registry  
- запуск GitLab CI  

---

### 4. Деплой

**GitLab pipeline:**

- деплоит в Kubernetes  
- обновляет inference слой  

---

### 5. Рост и падение интенсивности (TPS)

- Пользователь меняет helm/producer/values.yaml:  
  `tps: "5" → "100"`  
- Producer начинает отправлять данные с большим TPS   
- Пользователь наблюдает в мониторинге:
    * рост реплик пода
    * рост утилизации CPU
    * рост очереди Kafka (Kafka lag)
- Пользователь получает уведомления в мессенджер Telegram:
    * очередь Kafka выросла значительно
    * Утилизация CPU реплик под превысила пороговые значения


---

## Kubernetes инфраструктура

**Разворачиваются:**

- Kafka + Zookeeper  
- PostgreSQL  
- Airflow  
- MLflow  
- MinIO  
- Kafka UI  
- Producer / Consumer  

---

## Мониторинг

### OTUS dashboard

**Отслеживает:**
- data drift  
- утилизация CPU
- утилизация Memory
- количество реплик
- Kafka lag
- Пропускная способность (TPS)   
- Fraud rate

---

## ML модель

- Задача: binary classification (fraud / non-fraud)  
- Алгоритм: XGBoost  

**Метрики:**
- ROC-AUC  
- Precision / Recall  
- F1-score  
- кастомная метрика ROC-AUC + min_inference_time

---

## Docker

**Контейнеризированы:**

- producer  
- consumer  
- trainer  

---

## Запуск проекта

### 1. Подготовка проекта в Gitlab, регистрация Gitlab-Runner, добавление пользовательских переменных
### 2. Запуск пайплайна в Gitlab, выполнение джоб infra и deploy
### 3. Запуск DAG Airflow
### 4. Ручное согласование запуска джобы model для развертывания модели
### 5. Cleanup удаление облачных ресурсов 

---

## Сравнение с GitHub Actions

<img src="png/table.png?raw=true" alt="Сравнение с GitHub Actions" title="Сравнение с GitHub Actions" width="100%"> <br>

---

## Выводы

Для развертывания системы анти-фрод в продуктиве Gitlab демонстрирует преимущества и более гибкий подход. Однако в рамках учебных проектов GitHub Actions является хорошей альтернативой.


