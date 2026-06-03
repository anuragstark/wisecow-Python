#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-east-1"
CLUSTER_NAME="wisecow-cluster"
NAMESPACE="wisecow"

echo -e "${GREEN}Starting Wisecow deployment...${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required tools
echo -e "${YELLOW}Checking required tools...${NC}"
required_tools=("aws" "kubectl" "helm" "terraform")
for tool in "${required_tools[@]}"; do
    if ! command_exists "$tool"; then
        echo -e "${RED}Error: $tool is not installed${NC}"
        exit 1
    fi
done

# Deploy infrastructure with Terraform
echo -e "${YELLOW}Deploying infrastructure with Terraform...${NC}"
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
cd ..

# Update kubeconfig
echo -e "${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# Run Ansible playbook for cluster setup
echo -e "${YELLOW}Setting up cluster components with Ansible...${NC}"
ansible-playbook ansible/setup-cluster.yaml

# Wait for ingress controller to be ready
echo -e "${YELLOW}Waiting for ingress controller to be ready...${NC}"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Deploy the application
echo -e "${YELLOW}Deploying Wisecow application...${NC}"
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/cluster-issuer.yaml
kubectl apply -f k8s/ingress.yaml

# Wait for deployment to be ready
echo -e "${YELLOW}Waiting for deployment to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/wisecow-deployment -n "$NAMESPACE"

# Get the LoadBalancer URL
echo -e "${YELLOW}Getting LoadBalancer URL...${NC}"
LB_URL=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}LoadBalancer URL: http://$LB_URL${NC}"
echo -e "${GREEN}Configure your domain to point to this LoadBalancer${NC}"
echo -e "${GREEN}Application will be available at: https://wisecow.yourdomain.com${NC}"

# Show pod status
echo -e "${YELLOW}Current pod status:${NC}"
kubectl get pods -n "$NAMESPACE"
