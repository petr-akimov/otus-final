from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
from airflow.providers.cncf.kubernetes.secret import Secret
from airflow.utils.dates import days_ago
from datetime import timedelta
from airflow.operators.python import PythonOperator  
import requests  

from kubernetes.client import V1Volume, V1VolumeMount, V1PersistentVolumeClaimVolumeSource

GITHUB_TOKEN = "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"
GITHUB_OWNER = "petr-akimov"
GITHUB_REPO = "otus-final"
EVENT_TYPE = "trigger-model"

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': days_ago(1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    dag_id='model_training',
    default_args=default_args,
    description='Train model + build + push image',
    schedule_interval='@daily',
    catchup=False,
    max_active_runs=1,
    tags=['ml', 'training'],
) as dag:

    aws_access_key = Secret(
        deploy_type='env',
        deploy_target='AWS_ACCESS_KEY_ID',
        secret='minio-credentials',
        key='AWS_ACCESS_KEY_ID',
    )

    aws_secret_key = Secret(
        deploy_type='env',
        deploy_target='AWS_SECRET_ACCESS_KEY',
        secret='minio-credentials',
        key='AWS_SECRET_ACCESS_KEY',
    )

    def resolve_dataset(**context):
        dag_run = context.get("dag_run")
        if dag_run and dag_run.conf and "drift_dataset" in dag_run.conf:
            drift_dataset = dag_run.conf["drift_dataset"]
            print(f"[DAG] Triggered by drift on {drift_dataset}")
            if drift_dataset == "a.csv":
                dataset = "b.csv"
            else:
                dataset = "a.csv"
        else:
            dataset = "a.csv"
            print("[DAG] Manual run → using default a.csv")
        print(f"[DAG] Training dataset: {dataset}")
        return f"s3://datasets/{dataset}"
        
    resolve_dataset_task = PythonOperator(
        task_id="resolve_dataset",
        python_callable=resolve_dataset,
    )

    train_and_build = KubernetesPodOperator(
        task_id='train-and-build',
        name='train-and-build',
        namespace='otus',
        image='petrakimovdocker/trainer:v5',
        image_pull_policy='IfNotPresent',
        service_account_name='airflow',

        cmds=["bash", "/app/scripts/entrypoint-kaniko.sh"],
        
        env_vars={
            'TRAIN_DATA_PATH': "{{ ti.xcom_pull(task_ids='resolve_dataset') }}",
            'MLFLOW_TRACKING_URI': 'http://mlflow.otus.svc.cluster.local:5000',
            'EXPERIMENT_NAME': 'fraud_detection',
            'MLFLOW_S3_ENDPOINT_URL': 'http://minio.otus.svc.cluster.local:9000'
        },

        secrets=[aws_access_key, aws_secret_key],

        volume_mounts=[
            V1VolumeMount(
                name='workspace',
                mount_path='/app/workspace' 
            )
        ],

        volumes=[
            V1Volume(
                name='workspace',
                persistent_volume_claim=V1PersistentVolumeClaimVolumeSource(
                    claim_name='airflow-task-data'
                )
            )
        ],

        get_logs=True,
        is_delete_operator_pod=False,
        do_xcom_push=True,  # +
    )
    
    def trigger_gha(**ctx):
        try:
            v = ctx["ti"].xcom_pull(task_ids="train-and-build")

            model_version = (
                v.get("model_version") if isinstance(v, dict) else v
            )

            url = f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/dispatches"

            headers = {
                "Authorization": f"token {GITHUB_TOKEN}",
                "Accept": "application/vnd.github+json",
            }

            payload = {
                "event_type": EVENT_TYPE,
                "client_payload": {
                    "MODEL_VERSION": str(model_version)
                },
            }

            response = requests.post(
                url,
                headers=headers,
                json=payload,
                timeout=10,
            )

            if response.status_code >= 300:
                print("GitHub trigger failed:", response.status_code, response.text)

        except Exception as e:
            print("Trigger error:", str(e))


    trigger_gha_task = PythonOperator(
        task_id="trigger_gha",
        python_callable=trigger_gha,
    )


    resolve_dataset_task >> train_and_build >> trigger_gha_task