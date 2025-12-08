#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting initialization...${NC}"

# Function to install Fluentd
install_fluentd() {
    echo -e "${YELLOW}Installing Fluentd...${NC}"
    helm repo add fluent https://fluent.github.io/helm-charts
    helm repo update
    helm install my-fluentd-release fluent/fluentd
    echo -e "${GREEN}Fluentd installed successfully${NC}"
}

# Function to install kube-prometheus-stack (Prometheus + Grafana)
install_kube_prometheus() {
    echo -e "${YELLOW}Installing kube-prometheus-stack (Prometheus + Grafana)...${NC}"
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Install with admission webhooks disabled (required for Kind clusters)
    helm install kube-prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheusOperator.admissionWebhooks.enabled=false \
        --set prometheusOperator.tls.enabled=false \
        --timeout 10m
    
    echo -e "${GREEN}kube-prometheus-stack installed successfully${NC}"
    echo -e "${YELLOW}Get Grafana admin password:${NC}"
    echo "  kubectl get secret --namespace monitoring kube-prometheus-grafana -o jsonpath=\"{.data.admin-password}\" | base64 -d ; echo"
}

# Main execution
install_fluentd
install_kube_prometheus

echo -e "${GREEN}Initialization complete!${NC}"
echo -e "${YELLOW}To access Grafana:${NC}"
echo -e "  kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80"
echo -e "${YELLOW}Get Grafana admin password:${NC}"
echo -e "  kubectl get secret --namespace monitoring kube-prometheus-grafana -o jsonpath=\"{.data.admin-password}\" | base64 -d ; echo"
