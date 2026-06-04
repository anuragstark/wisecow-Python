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

echo "Bootstrap Complete!"
echo "ArgoCD and Argo Rollouts have been installed, and your applications are deploying."
echo "You can check deployment status with: kubectl get pods -n wisecow"
