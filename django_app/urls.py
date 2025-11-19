from django.contrib import admin
from django.urls import path
from django.http import JsonResponse
import socket

def health_check(request):
    return JsonResponse({
        'status': 'healthy',
        'hostname': socket.gethostname()
    })

def home(request):
    return JsonResponse({
        'message': 'Hello from Django Kubernetes App!',
        'hostname': socket.gethostname(),
        'pod_ip': socket.gethostbyname(socket.gethostname())
    })

urlpatterns = [
    path('admin/', admin.site.urls),
    path('health/', health_check),
    path('', home),
]
