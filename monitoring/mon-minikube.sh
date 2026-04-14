#!/bin/bash
set -e

NAMESPACE="monitoring"

echo ">>> Создаю namespace"
kubectl apply -f monitoring/00-namespace.yaml 

echo ">>> Добавляю Helm репозитории"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts 
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update 

echo ">>> Устанавливаю Loki + Promtail"
helm upgrade --install loki grafana/loki-stack -n $NAMESPACE -f monitoring/02-loki-values.yaml 

echo ">>> Устанавливаю kube-prometheus-stack (Prometheus + Grafana)"
helm upgrade --install kp prometheus-community/kube-prometheus-stack -n $NAMESPACE -f monitoring/01-kube-prom-values.yaml 
kubectl -n monitoring wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --timeout=180s

echo ">>> Устанавливаю metrics-server"
helm upgrade --install metrics-server metrics-server/metrics-server --namespace kube-system \
  --set-json 'args=["--kubelet-insecure-tls","--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP"]' \
  --set replicas=1 \
  --wait

echo ">>> Создаю дашборды Otus и Loki"
kubectl apply -f monitoring/03-grafana-loki-dashboards.yaml
kubectl apply -f monitoring/04-grafana-dashboards.yaml

echo ">>> Применяю PrometheusRule для алертов"
kubectl apply -f monitoring/06-prometheus-rules.yaml

kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana

echo ">>> Создаю Ingress для Grafana"
kubectl apply -f monitoring/05-grafana-ingress.yaml 

echo ">>> Устанавливаю Service Monitor"
kubectl apply -f monitoring/08-servicemonitor-consumer.yaml

echo ">>> Проверяю статус пода Grafana"
GRAFANA_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
GRAFANA_STATUS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].status.containerStatuses[?(@.name=="grafana")].state.waiting.reason}' 2>/dev/null || true)
READY_STATUS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)

echo "Текущий статус Grafana:"
echo "  Pod: $GRAFANA_POD"
echo "  Container Status: $GRAFANA_STATUS"
echo "  Ready Status: $READY_STATUS"

if [[ "$GRAFANA_STATUS" == "CrashLoopBackOff" ]] || [[ "$READY_STATUS" != "True" ]]; then
    echo ">>> Обнаружена проблема с Grafana ($GRAFANA_STATUS). Перезапускаю под..."
    kubectl delete pod -l app.kubernetes.io/name=grafana -n $NAMESPACE 
    
    echo ">>> Жду запуска нового пода Grafana"
    kubectl wait --for=condition=ready --timeout=30s pod -l app.kubernetes.io/name=grafana -n $NAMESPACE 
    
    echo ">>> Перезапуск Grafana завершен успешно"
else
    echo ">>> Grafana работает нормально, перезапуск не требуется"
fi

echo ">>> Проверяю финальный статус всех компонентов"
echo "Grafana:"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=grafana 

echo "Prometheus:"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=prometheus 

echo "Loki:"
kubectl get pods -n $NAMESPACE -l app=loki 

echo ">>> Мониторинг стек установлен успешно"
