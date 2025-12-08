# NGINX Observability on Kubernetes

A complete NGINX observability solution running on Kind (Kubernetes in Docker) with dual metric collection sources: NGINX Prometheus Exporter and Fluentd log parsing.

## Architecture Overview

```
NGINX Pods (3 replicas)
  ├─ NGINX Container (port 80)
  │   └─ Custom log format with $upstream_response_time
  │       └─ Logs → /var/log/containers/*.log
  │
  └─ NGINX Exporter Sidecar (port 9113)
      └─ Exposes 9 real-time metrics from /nginx_status

                    ↓ (logs written to disk)

Fluentd DaemonSet (2 pods)
  ├─ Tail /var/log/containers/nginx-*.log
  ├─ Parse with regex → extract fields (method, path, status_code, size, urt)
  └─ Generate 3 custom metrics with rich labels (port 24231)

                    ↓ (both scraped)

Prometheus (kube-prometheus-stack)
  ├─ Scrapes NGINX Exporter → 9 operational metrics
  ├─ Scrapes Fluentd → 3 log-based metrics
  └─ ServiceMonitor discovery via label: release=kube-prometheus

                    ↓

Grafana (included in kube-prometheus-stack)
  └─ Visualization and dashboards
```

## Components

### Infrastructure
- **Kind v0.30.0**: Kubernetes 1.33.4 cluster
  - 1 control-plane node
  - 2 worker nodes
  - Cluster name: `nginx-observability`

### Helm Charts
- **Fluentd**: v0.5.3 (app v1.17.1) - DaemonSet for log collection
- **kube-prometheus-stack**: Prometheus Operator, Prometheus, Grafana
- **nginx-chart**: v0.1.0 - Custom NGINX with exporter sidecar

### NGINX Configuration
- **Custom Log Format**:
  ```
  log_format custom_format '$remote_addr - $remote_user [$time_local] '
                          '"$request" $status $body_bytes_sent '
                          '"$http_referer" "$http_user_agent" '
                          '$upstream_response_time';
  ```
- **Key Variables**:
  - `$upstream_response_time`: Backend latency tracking
  - `$body_bytes_sent`: Response size tracking
  - `$status`: HTTP status codes

### Metrics Sources

#### 1. NGINX Prometheus Exporter (9 metrics)
Real-time operational metrics from `/nginx_status`:
- `nginx_connections_active`: Active client connections
- `nginx_connections_reading`: Connections reading requests
- `nginx_connections_writing`: Connections writing responses
- `nginx_connections_waiting`: Idle keepalive connections
- `nginx_http_requests_total`: Total HTTP requests
- `nginx_connections_accepted`: Accepted connections
- `nginx_connections_handled`: Handled connections
- `nginxexporter_build_info`: Exporter version info
- `up`: Exporter health status

#### 2. Fluentd Log-Based Metrics (3 metrics)
Parsed from NGINX access logs with rich labels:

1. **`nginx_size_bytes_total`** (counter)
   - Description: Total bytes sent in responses
   - Labels: `method`, `path`, `status_code`

2. **`nginx_request_status_code_total`** (counter)
   - Description: Request count by status code
   - Labels: `method`, `path`, `status_code`

3. **`nginx_upstream_time_seconds_hist`** (histogram)
   - Description: Backend response time distribution
   - Labels: `method`, `path`, `status_code`
   - Buckets: 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0

## Data Flow

### Log Collection Pipeline

1. **NGINX writes logs** to stdout with custom format
2. **Kubernetes captures** logs to `/var/log/containers/nginx-*.log`
3. **Fluentd DaemonSet tails** log files using tail plugin
4. **Regex parser extracts** structured fields:
   ```ruby
   /^(?<timestamp>.+) (?<stream>stdout|stderr)( (.))? (?<remote>[^ ]*) (?<host>[^ ]*) (?<user>[^ ]*) \[(?<time>[^\]]*)\] \"(?<method>\w+)(?:\s+(?<path>[^\"]*?)(?:\s+\S*)?)?\" (?<status_code>[^ ]*) (?<size>[^ ]*)(?:\s"(?<referer>[^\"]*)") "(?<agent>[^\"]*)" (?<urt>[^ ]*)$/
   ```
5. **Prometheus filter** generates metrics from parsed fields
6. **Prometheus scrapes** Fluentd metrics endpoint (`:24231/metrics`)

### 📈 Complete Metrics Comparison Table

#### NGINX Exporter Metrics (9 total)

| Metric Name | Type | Description | Labels | Use Case |
|-------------|------|-------------|--------|----------|
| `nginx_connections_active` | Gauge | Active client connections | None | Monitor current load |
| `nginx_connections_reading` | Gauge | Connections reading requests | None | Request processing |
| `nginx_connections_writing` | Gauge | Connections writing responses | None | Response processing |
| `nginx_connections_waiting` | Gauge | Idle keepalive connections | None | Connection pooling |
| `nginx_http_requests_total` | Counter | Total HTTP requests | None | Overall traffic volume |
| `nginx_connections_accepted` | Counter | Accepted connections | None | Connection success rate |
| `nginx_connections_handled` | Counter | Handled connections | None | Processing capacity |
| `nginxexporter_build_info` | Gauge | Exporter version info | `version`, `gitCommit` | Version tracking |
| `up` | Gauge | Exporter health status | None | Availability monitoring |

#### Fluentd Log-Based Metrics (3 total)

| Metric Name | Type | Description | Labels | Use Case |
|-------------|------|-------------|--------|----------|
| `nginx_size_bytes_total` | Counter | Total bytes sent in responses | `method`, `path`, `status_code` | Bandwidth per endpoint |
| `nginx_request_status_code_total` | Counter | Request count by status code | `method`, `path`, `status_code` | Error rate analysis |
| `nginx_upstream_time_seconds_hist` | Histogram | Backend response time distribution | `method`, `path`, `status_code` | Latency percentiles |

#### Key Differences: Exporter vs Fluentd Metrics

| Aspect | NGINX Exporter | Fluentd |
|--------|----------------|---------|
| **Source** | `/nginx_status` endpoint | Access log parsing |
| **Timing** | Real-time | Log-based (slight delay) |
| **Granularity** | Global counters | Per-request with labels |
| **Labels** | Minimal (version info only) | Rich: method, path, status_code |
| **Use Case** | Overall health/traffic | Request analysis, debugging |
| **Latency** | Not available | Histogram from $upstream_response_time |
| **Metric Count** | 9 metrics | 3 metrics |
| **Overhead** | Very low (single endpoint) | Higher (log parsing) |

## Quick Start

### Prerequisites
```bash
# Install Kind
brew install kind

# Install Helm
brew install helm

# Install kubectl
brew install kubectl
```

### 1. Create Kind Cluster
```bash
kind create cluster --config kind-config.yaml
```

### 2. Run Installation Script
```bash
chmod +x init.sh
./init.sh
```

This will install:
- Fluentd DaemonSet with custom configuration
- kube-prometheus-stack (Prometheus + Grafana)
- NGINX Helm chart with exporter sidecar

### 3. Verify Installation
```bash
# Check all pods are running
kubectl get pods -A

# Check Helm releases
helm list

# Check Fluentd pods
kubectl get pods -l app.kubernetes.io/name=fluentd

# Check NGINX pods
kubectl get pods -l app.kubernetes.io/name=nginx-chart

# Check Prometheus
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
```

### 4. Access Services

#### Grafana
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
```
- URL: http://localhost:3000
- Username: `admin`
- Password: `prom-operator`

#### Prometheus
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-kube-prome-prometheus 9090:9090
```
- URL: http://localhost:9090

#### NGINX Exporter Metrics
```bash
kubectl port-forward svc/nginx-server-nginx-chart 9113:9113
curl http://localhost:9113/metrics
```

#### Fluentd Metrics
```bash
kubectl port-forward svc/my-fluentd-release 24231:24231
curl http://localhost:24231/metrics
```

## Configuration Files

### Fluentd Configuration (`fluentd-values.yaml`)

#### Sources (04_sources.conf)
- Monitors Fluentd itself with `prometheus_tail_monitor`
- Tails container logs from `/var/log/containers/*.log`
- Parses logs with regex to extract fields
- Outputs to Fluentd metrics plugin

#### Filters (04_filters.conf)
- Matches logs from tag `kubernetes.**`
- Generates three Prometheus metrics:
  1. Counter for response size
  2. Counter for status codes
  3. Histogram for upstream latency

### NGINX Chart Files

- **Chart.yaml**: Helm chart metadata
- **values.yaml**: Configuration including custom log format
- **templates/deployment.yaml**: NGINX + exporter sidecar
- **templates/service.yaml**: Service exposing ports 80 and 9113
- **templates/configmap.yaml**: NGINX configuration with custom log format
- **templates/servicemonitor.yaml**: Prometheus discovery configuration

## Useful Commands

### Testing Metrics

```bash
# Generate traffic to NGINX
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  sh -c 'for i in $(seq 1 100); do curl -s http://nginx-server-nginx-chart; done'

# Query Prometheus for Fluentd metrics
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s http://kube-prometheus-kube-prome-prometheus.monitoring:9090/api/v1/query?query=nginx_request_status_code_total

# Check Fluentd logs
kubectl logs -l app.kubernetes.io/name=fluentd -f
```

### Debugging

```bash
# Check Fluentd configuration
kubectl exec -it <fluentd-pod> -- cat /etc/fluent/config.d/04_sources.conf
kubectl exec -it <fluentd-pod> -- cat /etc/fluent/config.d/04_filters.conf

# Check NGINX configuration
kubectl exec -it <nginx-pod> -c nginx -- cat /etc/nginx/conf.d/default.conf

# Check ServiceMonitors
kubectl get servicemonitor
kubectl describe servicemonitor nginx-server-nginx-chart
kubectl describe servicemonitor my-fluentd-release
```

### Cleanup

```bash
# Delete Kind cluster
kind delete cluster --name nginx-observability

# Or uninstall Helm releases
helm uninstall nginx-server
helm uninstall my-fluentd-release
helm uninstall -n monitoring kube-prometheus
```

## Troubleshooting

### Common Issues

1. **Admission Webhook ImagePullBackOff in Kind**
   - Solution: Disable webhooks in kube-prometheus-stack
   - Flag: `--set prometheusOperator.admissionWebhooks.enabled=false`

2. **Helm Upgrade Timeout**
   - Solution: Uninstall and reinstall instead of upgrade
   - Command: `helm uninstall <release> && helm install <release> ...`

3. **Fluentd Not Parsing Logs**
   - Check regex pattern matches log format exactly
   - Verify volume mounts: `/var/log` and `/var/lib/docker/containers`

4. **Metrics Not Appearing in Prometheus**
   - Verify ServiceMonitor has label: `release: kube-prometheus`
   - Check Prometheus targets: Prometheus UI → Status → Targets

## PromQL Examples

```promql
# Request rate by status code
rate(nginx_request_status_code_total[5m])

# Error rate (4xx + 5xx)
sum(rate(nginx_request_status_code_total{status_code=~"4..|5.."}[5m]))

# 95th percentile latency
histogram_quantile(0.95, rate(nginx_upstream_time_seconds_hist_bucket[5m]))

# Total bytes sent
sum(nginx_size_bytes_total)

# Active connections (from exporter)
nginx_connections_active
```

## Technical Specifications

- **Kubernetes Version**: 1.33.4
- **Kind Image**: kindest/node:v1.33.4@sha256:0d7006c83f8dcbd353cce0c131b046619f83464408f088036a1ed538e0d67fc4
- **NGINX Image**: nginx:latest
- **NGINX Exporter Image**: nginx/nginx-prometheus-exporter:0.10.0
- **Fluentd Chart Version**: 0.5.3
- **Fluentd App Version**: 1.17.1

## License

MIT
