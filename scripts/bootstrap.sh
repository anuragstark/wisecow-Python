#!/bin/bash

# Exit on any error
set -e

echo "Starting Wisecow Cluster Bootstrap..."

# 1. Install ArgoCD
echo "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts

# 2. Install Argo Rollouts Controller
echo "Installing Argo Rollouts Controller..."
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml --server-side --force-conflicts

# 3. Install Ingress Nginx Controller
echo "Installing Ingress Nginx Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true \
  --set controller.metrics.serviceMonitor.additionalLabels.release="prometheus" \
  --wait

# 3. Wait for ArgoCD to be ready (required before applying applications)
echo "Waiting for ArgoCD controllers to start (this may take a few minutes)..."
kubectl wait --for=condition=ready pod --all -n argocd --timeout=600s

# 4. Wait for Argo Rollouts (non-blocking - it will start once resources free up)
echo "Waiting for Argo Rollouts controller..."
kubectl wait --for=condition=ready pod --all -n argo-rollouts --timeout=600s || echo "[WARN] Argo Rollouts is still starting. It will become ready shortly."

# 4. Apply our GitOps Applications
# Note: You MUST update the repository URL in argocd/wisecow-application.yaml before running this!
echo "Deploying Wisecow App and Prometheus Stack via ArgoCD..."
kubectl apply -f argocd/prometheus-application.yaml
kubectl apply -f argocd/wisecow-application.yaml
kubectl apply -f argocd/argocd-ingress.yaml

echo "Bootstrap Complete!"
echo "ArgoCD and Argo Rollouts have been installed, and your applications are deploying."
echo "You can check deployment status with: kubectl get pods -n wisecow"

echo ""
echo "Waiting for AWS to provision the Load Balancer (this takes ~60 seconds)..."
LB_URL=""
while [ -z "$LB_URL" ]; do
  sleep 5
  LB_URL=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
done

echo "=========================================================================="
echo " SUCCESS! Your Load Balancer is ready."
echo "Add these THREE CNAME records in DNS pointing to this address:"
echo "1. www.checkmypro.online"
echo "2. argocd.checkmypro.online"
echo "3. grafana.checkmypro.online"
echo ""
echo "    $LB_URL"
echo ""
echo "=========================================================================="
