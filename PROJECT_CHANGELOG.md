# Wisecow Python — V2 Changelog & Workflow

## 🚀 What We Changed (The "God-Tier" Upgrades)

We took the foundational Wisecow infrastructure project and upgraded both the application and the deployment architecture to match Senior DevOps Engineer standards.

### 1. Application Rewrite (Python Flask)
- **Old:** A basic `wisecow.sh` bash script using `netcat` to serve an HTTP response.
- **New:** A professional Python `Flask` microservice (`app.py`).
- **Why:** 
  - Proper HTTP handling and status codes.
  - Added a dedicated `/health` endpoint for Kubernetes readiness/liveness probes.
  - Integrated `prometheus_client` to expose custom application metrics at `/metrics` for Grafana to scrape.
  - Rewritten `Dockerfile` using `python:3.11-slim`, running as a non-root user via `gunicorn`.

### 2. Infrastructure as Code (Terraform Modules)
- **Old:** A single, monolithic `main.tf` containing all AWS resources.
- **New:** Refactored into reusable Terraform modules: `terraform/modules/vpc` and `terraform/modules/eks`.
- **Why:** This is the enterprise standard. It keeps code DRY (Don't Repeat Yourself) and makes the infrastructure highly scalable and readable.

### 3. DevSecOps (Checkov Scanning)
- **Old:** Standard build-and-push CI/CD pipeline.
- **New:** Integrated **Checkov** into the `.github/workflows/ci-cd.yaml`.
- **Why:** On every push, Checkov automatically scans the Terraform and Helm code for security misconfigurations. This demonstrates "Shift-Left" security practices.

### 4. Advanced GitOps (ArgoCD & Argo Rollouts)
- **Old:** Standard Kubernetes `Deployment` applied manually or via `kubectl`.
- **New:** 
  - Packaged the app as a **Helm Chart** (`helm/wisecow`).
  - Switched from standard `Deployment` to an **Argo Rollout** (`helm/wisecow/templates/rollout.yaml`).
  - Implemented a **Canary Deployment Strategy** (routes 20% of traffic to the new version first, then pauses for manual verification).
  - Deployed entirely via **ArgoCD** applications (`argocd/wisecow-application.yaml`).

---

## 🔄 The New End-to-End Workflow

Here is exactly how code flows from a developer's laptop to production in this upgraded architecture:

1. **Code Commit**: You edit `app.py` or infrastructure code and push to GitHub.
2. **CI/CD Security Scan**: GitHub Actions triggers. It first runs **Checkov** to ensure you haven't introduced any security vulnerabilities (e.g., containers running as root, open security groups).
3. **CI/CD Build & Push**: If the scan passes, GitHub Actions builds the Python Docker image and pushes it to GHCR (`ghcr.io`).
4. **GitOps Sync**: **ArgoCD** (running in the EKS cluster) detects a change in the GitHub repository's Helm chart or image tag.
5. **Canary Deployment**: ArgoCD applies the change via the **Argo Rollouts** controller.
6. **Traffic Routing**: The Rollout deploys the new pods but only routes **20%** of live user traffic to them.
7. **Observability Check**: You look at your Grafana dashboard (populated by the new Python `/metrics` endpoint). If error rates are 0% and latency is good, you manually promote the rollout.
8. **Full Promotion**: Argo Rollouts routes 100% of traffic to the new Python pods and scales down the old ones. Zero downtime!
