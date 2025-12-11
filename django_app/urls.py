from django.contrib import admin
from django.urls import path
from django.http import HttpResponse, JsonResponse
import socket
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST, Counter, Histogram, Gauge
import time

# Создаем метрики с префиксом django_ как в задании
DJANGO_HTTP_REQUESTS_TOTAL = Counter('django_http_requests_total', 
                                     'Total HTTP requests in Django app',
                                     ['method', 'endpoint', 'status'])

DJANGO_HTTP_REQUEST_DURATION = Histogram('django_http_request_duration_seconds',
                                        'HTTP request duration in Django app',
                                        ['method', 'endpoint'])

DJANGO_ACTIVE_USERS = Gauge('django_active_users', 'Active users in Django app')

def health_check(request):
    start_time = time.time()
    DJANGO_ACTIVE_USERS.inc()  # Увеличиваем счетчик активных пользователей
    
    response = JsonResponse({
        'status': 'healthy',
        'hostname': socket.gethostname()
    })
    
    duration = time.time() - start_time
    DJANGO_HTTP_REQUESTS_TOTAL.labels('GET', '/health', '200').inc()
    DJANGO_HTTP_REQUEST_DURATION.labels('GET', '/health').observe(duration)
    DJANGO_ACTIVE_USERS.dec()  # Уменьшаем после завершения
    
    return response

def home(request):
    start_time = time.time()
    DJANGO_ACTIVE_USERS.inc()
    
    response = JsonResponse({
        'message': 'Hello from Django Kubernetes App!',
        'hostname': socket.gethostname(),
        'pod_ip': socket.gethostbyname(socket.gethostname()),
        'metrics': 'http://' + request.get_host() + '/metrics'
    })
    
    duration = time.time() - start_time
    DJANGO_HTTP_REQUESTS_TOTAL.labels('GET', '/', '200').inc()
    DJANGO_HTTP_REQUEST_DURATION.labels('GET', '/').observe(duration)
    DJANGO_ACTIVE_USERS.dec()
    
    return response

def metrics_view(request):
    """Endpoint для метрик Prometheus"""
    # Не считаем этот запрос в метриках
    response = HttpResponse(generate_latest(), content_type=CONTENT_TYPE_LATEST)
    return response

urlpatterns = [
    path('admin/', admin.site.urls),
    path('health/', health_check),
    path('', home),
    path('metrics', metrics_view),
]
