#!/bin/bash

# Health check script for Wisecow application
# This script performs comprehensive health checks

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="wisecow"
DEPLOYMENT="wisecow-deployment"
SERVICE="wisecow-service"

echo -e "${GREEN}=== Wisecow Health Check ===${NC}"

# Function to check if a command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
        return 0
    else
        echo -e "${RED}✗ $1${NC}"
        return 1
    fi
}

# Check cluster connectivity
echo -e "${YELLOW}Checking cluster connectivity...${NC}"
kubectl cluster-info &>/dev/null
check_status "Cluster connectivity"

# Check namespace exists
echo -e "${YELLOW}Checking namespace...${NC}"
kubectl get namespace "$NAMESPACE" &>/dev/null
check_status "Namespace $NAMESPACE exists"

# Check deployment status
echo -e "${YELLOW}Checking deployment...${NC}"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" &>/dev/null
check_status "Deployment $DEPLOYMENT exists"

# Check if deployment is ready
READY_REPLICAS=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
DESIRED_REPLICAS=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')

if [ "$READY_REPLICAS" = "$DESIRED_REPLICAS" ]; then
    echo -e "${GREEN}✓ Deployment is ready ($READY_REPLICAS/$DESIRED_REPLICAS replicas)${NC}"
else
    echo -e "${RED}✗ Deployment not ready ($READY_REPLICAS/$DESIRED_REPLICAS replicas)${NC}"
fi

# Check pod status
echo -e "${YELLOW}Checking pods...${NC}"
RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=wisecow --field-selector=status.phase=Running -o name | wc -l)
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=wisecow -o name | wc -l)

if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓ All pods are running ($RUNNING_PODS/$TOTAL_PODS)${NC}"
else
    echo -e "${RED}✗ Some pods are not running ($RUNNING_PODS/$TOTAL_PODS)${NC}"
    echo -e "${YELLOW}Pod details:${NC}"
    kubectl get pods -n "$NAMESPACE" -l app=wisecow
fi

# Check service
echo -e "${YELLOW}Checking service...${NC}"
kubectl get service "$SERVICE" -n "$NAMESPACE" &>/dev/null
check_status "Service $SERVICE exists"

# Check ingress
echo -e "${YELLOW}Checking ingress...${NC}"
kubectl get ingress -n "$NAMESPACE" &>/dev/null
check_status "Ingress exists"

# Check ingress controller
echo -e "${YELLOW}Checking ingress controller...${NC}"
kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --field-selector=status.phase=Running &>/dev/null
check_status "Ingress controller is running"

# Check certificate (if exists)
echo -e "${YELLOW}Checking TLS certificate...${NC}"
if kubectl get certificates -n "$NAMESPACE" &>/dev/null; then
    CERT_READY=$(kubectl get certificates -n "$NAMESPACE" -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
    if [ "$CERT_READY" = "True" ]; then
        echo -e "${GREEN}✓ TLS certificate is ready${NC}"
    else
        echo -e "${YELLOW}⚠ TLS certificate not ready yet${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No TLS certificates found${NC}"
fi

# Test application endpoint (if LoadBalancer is ready)
echo -e "${YELLOW}Testing application endpoint...${NC}"
LB_URL=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -n "$LB_URL" ]; then
    if curl -s -o /dev/null -w "%{http_code}" "http://$LB_URL" | grep -q "200\|302\|301"; then
        echo -e "${GREEN}✓ Application endpoint is responding${NC}"
    else
        echo -e "${RED}✗ Application endpoint not responding${NC}"
    fi
else
    echo -e "${YELLOW}⚠ LoadBalancer URL not available${NC}"
fi

# Check resource usage
echo -e "${YELLOW}Checking resource usage...${NC}"
if kubectl top pods -n "$NAMESPACE" &>/dev/null; then
    echo -e "${GREEN}✓ Resource metrics available${NC}"
    kubectl top pods -n "$NAMESPACE"
else
    echo -e "${YELLOW}⚠ Resource metrics not available (metrics server may not be installed)${NC}"
fi

# Summary
echo -e "${GREEN}=== Health Check Complete ===${NC}"
echo -e "${YELLOW}Summary:${NC}"
echo "- Namespace: $NAMESPACE"
echo "- Deployment: $DEPLOYMENT"
echo "- Service: $SERVICE"
echo "- Running Pods: $RUNNING_PODS/$TOTAL_PODS"
echo "- LoadBalancer: $LB_URL"

if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo -e "${GREEN}Overall Status: HEALTHY${NC}"
    exit 0
else
    echo -e "${RED}Overall Status: UNHEALTHY${NC}"
    exit 1
fi
