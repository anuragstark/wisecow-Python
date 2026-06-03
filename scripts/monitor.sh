#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="wisecow"

echo -e "${GREEN}=== Wisecow Application Monitoring ===${NC}"

# Check cluster connection
echo -e "${YELLOW}Checking cluster connectivity...${NC}"
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}Cannot connect to cluster. Please check your kubeconfig.${NC}"
    exit 1
fi

# Check namespace
echo -e "${YELLOW}Checking namespace...${NC}"
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}Namespace $NAMESPACE not found${NC}"
    exit 1
fi

# Check deployment status
echo -e "${BLUE}Deployment Status:${NC}"
kubectl get deployment -n "$NAMESPACE"
echo

# Check pod status
echo -e "${BLUE}Pod Status:${NC}"
kubectl get pods -n "$NAMESPACE" -o wide
echo

# Check service status
echo -e "${BLUE}Service Status:${NC}"
kubectl get svc -n "$NAMESPACE"
echo

# Check ingress status
echo -e "${BLUE}Ingress Status:${NC}"
kubectl get ingress -n "$NAMESPACE"
echo

# Check certificate status
echo -e "${BLUE}Certificate Status:${NC}"
kubectl get certificates -n "$NAMESPACE" 2>/dev/null || echo "No certificates found"
echo

# Check recent events
echo -e "${BLUE}Recent Events:${NC}"
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
echo

# Check resource usage
echo -e "${BLUE}Resource Usage:${NC}"
kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "Metrics server not available"
echo

# Check LoadBalancer URL
echo -e "${BLUE}LoadBalancer Information:${NC}"
LB_URL=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "$LB_URL" ]; then
    echo -e "${GREEN}LoadBalancer URL: http://$LB_URL${NC}"
else
    echo -e "${YELLOW}LoadBalancer URL not available yet${NC}"
fi

# Health check
echo -e "${BLUE}Health Check:${NC}"
READY_PODS=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | wc -w)
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' | wc -w)

if [ "$READY_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓ All pods are running ($READY_PODS/$TOTAL_PODS)${NC}"
else
    echo -e "${RED}✗ Some pods are not running ($READY_PODS/$TOTAL_PODS)${NC}"
fi

echo -e "${GREEN}=== Monitoring Complete ===${NC}"
