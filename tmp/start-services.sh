#!/bin/bash
kubectl delete namespace otus
#kubectl delete namespace monitoring
kubectl create namespace otus
#kubectl create namespace monitoring
kubectl apply -n otus -f k8s 
kubectl -n otus wait --for=condition=ready pod -l app=airflow --timeout=240s 
POD_NAME=$(kubectl -n otus get pods -l app=airflow -o name | head -1 | cut -d/ -f2)
kubectl cp dags/drift_detection.py otus/$POD_NAME:/opt/airflow/dags/drift_detection.py -c airflow 
