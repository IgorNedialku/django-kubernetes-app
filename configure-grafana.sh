#!/bin/bash

echo "=== Настройка Grafana через API ==="

# 1. Получаем пароль Grafana
echo "1. Получение пароля Grafana..."
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 --decode)
echo "   Пароль: $GRAFANA_PASSWORD"

# 2. Запускаем port-forward в фоне
echo "2. Запуск port-forward Grafana..."
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 > /dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 10  # Ждем стабилизации

# 3. Функция для проверки доступности Grafana
check_grafana() {
    echo "3. Проверка доступности Grafana..."
    for i in {1..30}; do
        if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
            echo "   ✅ Grafana доступна"
            return 0
        fi
        echo "   ⏳ Ожидание Grafana... ($i/30)"
        sleep 2
    done
    echo "   ❌ Grafana недоступна"
    return 1
}

check_grafana || exit 1

# 4. Настройка источника данных Prometheus (если не настроен)
echo "4. Настройка источника данных Prometheus..."
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "admin:$GRAFANA_PASSWORD" \
  "http://localhost:3000/api/datasources" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "access": "proxy",
    "url": "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090",
    "basicAuth": false,
    "isDefault": true
  }' 2>/dev/null | grep -q '"message":"Datasource added"' && echo "   ✅ Prometheus настроен" || echo "   ℹ️ Prometheus уже настроен"

# 5. Настройка источника данных Loki
echo "5. Настройка источника данных Loki..."
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "admin:$GRAFANA_PASSWORD" \
  "http://localhost:3000/api/datasources" \
  -d '{
    "name": "Loki",
    "type": "loki",
    "access": "proxy",
    "url": "http://loki.monitoring.svc.cluster.local:3100",
    "basicAuth": false,
    "isDefault": false
  }' 2>/dev/null | grep -q '"message":"Datasource added"' && echo "   ✅ Loki настроен" || echo "   ℹ️ Loki уже настроен"

# 6. Импорт дашборда Django (ID: 18243)
echo "6. Импорт дашборда Django (ID: 18243)..."
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "admin:$GRAFANA_PASSWORD" \
  "http://localhost:3000/api/dashboards/import" \
  -d '{
    "dashboard": {
      "id": null,
      "uid": null,
      "title": "Django Monitoring",
      "tags": ["django"],
      "timezone": "browser",
      "schemaVersion": 16,
      "version": 0
    },
    "folderId": 0,
    "overwrite": true,
    "inputs": [
      {
        "name": "DS_PROMETHEUS",
        "type": "datasource",
        "pluginId": "prometheus",
        "value": "Prometheus"
      }
    ],
    "folderUid": ""
  }' 2>/dev/null && echo "   ✅ Дашборд Django импортирован"

# 7. Импорт дашборда Kubernetes (ID: 315)
echo "7. Импорт дашборда Kubernetes (ID: 315)..."
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "admin:$GRAFANA_PASSWORD" \
  "http://localhost:3000/api/dashboards/import" \
  -d '{
    "dashboard": {
      "id": null,
      "uid": null,
      "title": "Kubernetes Cluster Monitoring",
      "tags": ["kubernetes"],
      "timezone": "browser",
      "schemaVersion": 16,
      "version": 0
    },
    "folderId": 0,
    "overwrite": true,
    "inputs": [
      {
        "name": "DS_PROMETHEUS",
        "type": "datasource",
        "pluginId": "prometheus",
        "value": "Prometheus"
      }
    ],
    "folderUid": ""
  }' 2>/dev/null && echo "   ✅ Дашборд Kubernetes импортирован"

# 8. Создание кастомного дашборда для Django логов
echo "8. Создание дашборда для Django логов..."
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "admin:$GRAFANA_PASSWORD" \
  "http://localhost:3000/api/dashboards/db" \
  -d '{
    "dashboard": {
      "id": null,
      "title": "Django Application Logs",
      "tags": ["django", "logs"],
      "timezone": "browser",
      "panels": [
        {
          "id": 1,
          "title": "Application Logs",
          "type": "logs",
          "datasource": "Loki",
          "targets": [
            {
              "expr": "{app=\"django-app\"}",
              "refId": "A"
            }
          ],
          "options": {
            "showLabels": true,
            "showTime": true,
            "wrapLogMessage": true,
            "prettifyLogMessage": true,
            "enableLogDetails": true
          },
          "gridPos": {
            "h": 20,
            "w": 24,
            "x": 0,
            "y": 0
          }
        }
      ],
      "time": {
        "from": "now-1h",
        "to": "now"
      },
      "refresh": "30s"
    },
    "overwrite": true
  }' 2>/dev/null && echo "   ✅ Дашборд логов создан"

# 9. Останавливаем port-forward
echo "9. Остановка port-forward..."
kill $PORT_FORWARD_PID 2>/dev/null
wait $PORT_FORWARD_PID 2>/dev/null

echo ""
echo "=== НАСТРОЙКА ЗАВЕРШЕНА ==="
echo ""
echo "Для доступа к Grafana:"
echo "1. kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "2. Откройте: http://localhost:3000"
echo "3. Логин: admin"
echo "4. Пароль: $GRAFANA_PASSWORD"
echo ""
echo "Доступные дашборды:"
echo "   - Django Monitoring (импортирован)"
echo "   - Kubernetes Cluster Monitoring (импортирован)"
echo "   - Django Application Logs (создан)"
echo ""
echo "Для генерации тестовых данных выполните:"
echo "   MINIKUBE_IP=\$(minikube ip)"
echo "   NODE_PORT=\$(kubectl get svc -n django-app django-app -o jsonpath='{.spec.ports[0].nodePort}')"
echo "   for i in {1..20}; do curl -s \"http://\$MINIKUBE_IP:\$NODE_PORT/health/\"; sleep 2; done"
