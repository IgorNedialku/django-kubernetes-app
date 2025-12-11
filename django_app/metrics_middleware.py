from prometheus_client import Counter
import time

HTTP_REQUESTS_MIDDLEWARE = Counter(
    'http_requests_by_middleware_total',
    'HTTP requests counted by middleware',
    ['method', 'path', 'status']
)

class SimpleMetricsMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Пропускаем запросы к /metrics чтобы не считать их дважды
        if request.path == '/metrics':
            return self.get_response(request)
        
        response = self.get_response(request)
        
        HTTP_REQUESTS_MIDDLEWARE.labels(
            request.method,
            request.path,
            response.status_code
        ).inc()
        
        return response
