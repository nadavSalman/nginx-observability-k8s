# NGINX Helm Chart

A Helm chart for deploying NGINX with Prometheus exporter for metrics collection.

## Features

- NGINX web server deployment
- NGINX Prometheus Exporter sidecar
- ConfigMap for NGINX configuration
- Service for HTTP and metrics endpoints
- ServiceMonitor for Prometheus scraping
- Configurable replicas and resources

## Installation

```bash
# Install the chart
helm install nginx-server ./nginx-chart

# Install with custom values
helm install nginx-server ./nginx-chart -f custom-values.yaml

# Install in a specific namespace
helm install nginx-server ./nginx-chart --namespace default --create-namespace
```

## Configuration

The following table lists the configurable parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of NGINX replicas | `3` |
| `image.repository` | NGINX image repository | `nginx` |
| `image.tag` | NGINX image tag | `latest` |
| `exporter.image.repository` | Exporter image repository | `nginx/nginx-prometheus-exporter` |
| `exporter.image.tag` | Exporter image tag | `0.10.0` |
| `exporter.port` | Exporter metrics port | `9113` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port for HTTP | `80` |
| `service.metricsPort` | Service port for metrics | `9113` |
| `nginx.config` | NGINX configuration | See values.yaml |

## Accessing the Application

```bash
# Port-forward to access NGINX
kubectl port-forward svc/nginx-server-nginx-chart 8080:80

# Access metrics
kubectl port-forward svc/nginx-server-nginx-chart 9113:9113
curl http://localhost:9113/metrics
```

## Prometheus Integration

The chart includes a ServiceMonitor resource for automatic Prometheus scraping. Ensure that the Prometheus Operator is installed in your cluster.

## Customizing NGINX Configuration

Edit the `nginx.config` value in `values.yaml` or provide a custom configuration via `--set` or a values file:

```yaml
nginx:
  config: |
    server {
        listen 80;
        server_name example.com;
        # Your custom configuration
    }
```

## Uninstalling

```bash
helm uninstall nginx-server
```
