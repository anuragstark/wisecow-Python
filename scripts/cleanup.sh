#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting cleanup...${NC}"

# Remove Kubernetes resources
echo -e "${YELLOW}Removing Kubernetes resources...${NC}"
kubectl delete -f k8s/ingress.yaml --ignore-not-found=true
kubectl delete -f k8s/service.yaml --ignore-not-found=true
kubectl delete -f k8s/deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/cluster-issuer.yaml --ignore-not-found=true

# Remove Helm releases
echo -e "${YELLOW}Removing Helm releases...${NC}"
helm uninstall cert-manager -n cert-manager --ignore-not-found
helm uninstall ingress-nginx -n ingress-nginx --ignore-not-found

# Remove namespaces
echo -e "${YELLOW}Removing namespaces...${NC}"
kubectl delete namespace wisecow --ignore-not-found=true
kubectl delete namespace cert-manager --ignore-not-found=true
kubectl delete namespace ingress-nginx --ignore-not-found=true

# Destroy infrastructure
echo -e "${YELLOW}Destroying infrastructure with Terraform...${NC}"
cd terraform
terraform destroy -auto-approve
cd ..

echo -e "${GREEN}Cleanup completed successfully!${NC}"
