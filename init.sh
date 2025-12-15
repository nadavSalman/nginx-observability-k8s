#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting initialization...${NC}"

# Function to install Fluent Bit
install_fluent_bit() {
    echo -e "${YELLOW}Installing Fluent Bit with NGINX log parsing...${NC}"
    helm repo add fluent https://fluent.github.io/helm-charts
    helm repo update
    helm upgrade --install fluent-bit fluent/fluent-bit -f fluent-bit/values.yaml
    
    # Patch ServiceMonitor label since chart doesn't support it directly
    echo -e "${YELLOW}Patching Fluent Bit ServiceMonitor label...${NC}"
    # Wait for ServiceMonitor to be created
    sleep 5
    kubectl label servicemonitor fluent-bit release=kube-prometheus --overwrite
    
    echo -e "${GREEN}Fluent Bit installed successfully${NC}"
    echo -e "${YELLOW}Fluent Bit will parse NGINX logs and export Prometheus metrics${NC}"
}

# Function to install kube-prometheus-stack (Prometheus + Grafana)
install_kube_prometheus() {
    echo -e "${YELLOW}Installing kube-prometheus-stack (Prometheus + Grafana)...${NC}"
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Install with admission webhooks disabled (required for Kind clusters)
    helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheusOperator.admissionWebhooks.enabled=false \
        --set prometheusOperator.tls.enabled=false \
        --timeout 10m
    
    echo -e "${GREEN}kube-prometheus-stack installed successfully${NC}"
    echo -e "${YELLOW}Get Grafana admin password:${NC}"
    echo "  kubectl get secret --namespace monitoring kube-prometheus-grafana -o jsonpath=\"{.data.admin-password}\" | base64 -d ; echo"
}

# Function to install NGINX chart
install_nginx() {
    echo -e "${YELLOW}Installing NGINX with exporter sidecar...${NC}"
    helm upgrade --install nginx-server ./nginx-chart
    echo -e "${GREEN}NGINX installed successfully${NC}"
}

# Main execution
install_fluent_bit
install_kube_prometheus
install_nginx

echo -e "${GREEN}Initialization complete!${NC}"
echo -e "${YELLOW}To access Grafana:${NC}"
echo -e "  kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80"
echo -e "${YELLOW}Get Grafana admin password:${NC}"
echo -e "  kubectl get secret --namespace monitoring kube-prometheus-grafana -o jsonpath=\"{.data.admin-password}\" | base64 -d ; echo"
