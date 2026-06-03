# Wisecow GitOps Platform

[![CI/CD Pipeline](https://github.com/anuragstark/wisecow-Python/actions/workflows/app-ci.yaml/badge.svg)](https://github.com/anuragstark/wisecow-Python/actions)
[![Infrastructure](https://github.com/anuragstark/wisecow-Python/actions/workflows/infra-deploy.yaml/badge.svg)](https://github.com/anuragstark/wisecow-Python/actions)

An enterprise-grade, cloud-native DevOps portfolio project demonstrating a fully automated **Test -> Build -> Scan -> Deploy** lifecycle using **GitOps** principles.

## Architecture Overview

This project deploys a containerized **Python Flask Microservice** onto an **AWS Elastic Kubernetes Service (EKS)** cluster. The entire lifecycle—from infrastructure provisioning to application canary deployments—is fully automated via **GitHub Actions** and **ArgoCD**, requiring zero local execution.

### Tech Stack
- **Application**: Python 3.11, Flask, Gunicorn (with Prometheus metrics)
- **Infrastructure as Code**: Terraform (Modularized VPC & EKS with S3 Remote Backend)
- **Containerization**: Docker, GitHub Container Registry (GHCR)
- **Orchestration**: Kubernetes (AWS EKS)
- **CI/CD Pipeline**: GitHub Actions
- **Continuous Deployment (GitOps)**: ArgoCD
- **Deployment Strategy**: Argo Rollouts (Canary Deployments)
- **DevSecOps**: Checkov (IaC Security), Trivy (Image Vulnerability Scanning)

---

## Key Features

### 1. DevSecOps CI/CD Pipeline (`app-ci.yaml`)
On every push to the repository:
- **Unit Testing**: Runs `pytest` against the Flask `/health` and `/metrics` endpoints.
- **Trivy Image Scan**: Builds the Docker image locally and runs Aqua Security Trivy to scan the OS and Python libraries for `CRITICAL` or `HIGH` vulnerabilities. Fails the build if any are found.
- **Publish**: Pushes the secure image to GHCR.

### 2. Infrastructure Automation (`infra-deploy.yaml`)
- **Modular Terraform**: Clean separation of `vpc` and `eks` modules.
- **Checkov Scanning**: Scans Terraform and Helm code for security misconfigurations.
- **Automated Provisioning**: GitHub Actions automatically runs `terraform apply` when the `terraform/` directory is modified.
- **Cluster Bootstrapping**: A post-apply script automatically installs ArgoCD and the Argo Rollouts controller onto the newly minted cluster.

### 3. GitOps & Canary Deployments (`argocd/`)
- **Zero-Touch Deployments**: ArgoCD monitors this repository. When a new image tag is detected, it automatically syncs the cluster state.
- **Argo Rollouts**: Replaces standard Kubernetes Deployments. Configured to route **20% of live traffic** to the new version (Canary) and pause for manual verification before 100% promotion, ensuring zero-downtime and safe releases.

---

## Getting Started

### Prerequisites
- AWS Account
- GitHub Repository Secrets configured:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`

### How to Deploy
You do **not** need to run any local scripts. 

1. **Deploy Infrastructure**: Navigate to the **Actions** tab in GitHub, select the `Infrastructure Deploy` workflow, and click "Run workflow". This will provision the VPC, EKS cluster, and install ArgoCD.
2. **Deploy Application**: ArgoCD will automatically detect the `argocd/wisecow-application.yaml` manifest and deploy the Helm chart.
3. **Trigger App Update**: Make a change to `app.py`, commit, and push. Watch the `app-ci.yaml` action test, scan, and push your image.
4. **Tear Down**: When finished, run the `Infrastructure Destroy` GitHub Action to safely clean up AWS resources.

---

## Repository Structure

```text
├── .github/workflows/       # GitHub Actions (app-ci, infra-deploy, infra-destroy)
├── argocd/                  # GitOps Application manifests (Wisecow & Prometheus)
├── helm/wisecow/            # Helm chart containing the Argo Rollout template
├── scripts/                 # Utility scripts (bootstrap.sh)
├── terraform/               # Modularized IaC (vpc and eks modules)
├── app.py                   # Python Flask Application
├── test_app.py              # Pytest unit tests
└── Dockerfile               # Production-ready multi-stage Dockerfile
```

---

## Let's Connect!
**Anurag Stark**

Feel free to reach out or connect with me on LinkedIn:
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/anuragstark/)
