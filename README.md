# Django Kubernetes App

High-availability Django application deployed on Kubernetes with CI/CD pipeline.

## Features

- Django 4.2 with PostgreSQL
- Kubernetes deployment with 4 replicas
- Load balancing between pods
- GitHub Actions CI/CD pipeline
- Prometheus metrics
- Health checks

## Architecture
Internet -> Ingress -> Service -> Django Pods (ReplicaSet) -> PostgreSQL
