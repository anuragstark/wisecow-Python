# 🎯 Wisecow Project — Interview Prep Guide

> **Generated on:** 2026-03-28  
> **Project:** Wisecow — Containerized DevOps Application  
> **Stack:** Docker · Kubernetes (EKS) · Terraform · Ansible · GitHub Actions · Prometheus
> **V2 Upgrades:** Python Flask · Terraform Modules · ArgoCD (GitOps) · Argo Rollouts (Canaries) · Checkov (SecOps)

---

## 🚨 V2 UPGRADE NOTICE 🚨
This project was recently upgraded to a **Senior DevOps standard**. When speaking in interviews, highlight these new features over the original ones:
1. **App:** It is no longer a bash script; it's a **Python Flask microservice** with native `/health` and `/metrics` (Prometheus) endpoints.
2. **IaC:** Terraform is now fully **Modularized** (`vpc` and `eks` modules) with remote S3 backends.
3. **Deployments:** We moved from basic `kubectl apply` to full **GitOps using ArgoCD**.
4. **Rollouts:** We replaced standard Deployments with **Argo Rollouts (Canary deployments)**.
5. **Security:** CI/CD now includes **Checkov** for automated IaC security scanning.
*(See `PROJECT_CHANGELOG.md` for full details).*
---

## 🔍 What is Wisecow? (The 30-second answer)

> *"Wisecow is a containerized web application that serves random fortune quotes styled with ASCII cow art (cowsay + fortune). The main focus of the project is not the app itself, but the DevOps infrastructure I built around it — Docker, Kubernetes on AWS EKS, Terraform for IaC, Ansible for cluster setup, and a GitHub Actions CI/CD pipeline."*

---

## 🏗️ Full Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Application** | Bash script (`wisecow.sh`) | HTTP server using `netcat`, serving cowsay+fortune |
| **Container** | Docker / Dockerfile | Ubuntu 22.04 base, port 4499 |
| **Container Registry** | GitHub Container Registry (ghcr.io) | Stores Docker images |
| **Orchestration** | Kubernetes (EKS) | Runs 3 replicas with rolling update |
| **Cloud** | AWS EKS + VPC | Managed K8s cluster |
| **IaC** | Terraform | Provisions EKS, VPC, subnets, IAM roles |
| **Cluster Setup** | Ansible | Installs kubectl, Helm, NGINX ingress, cert-manager, Prometheus |
| **CI/CD** | GitHub Actions | Build → Push to GHCR → Deploy to EKS |
| **TLS/HTTPS** | cert-manager + Let's Encrypt | Auto SSL for `www.checkmypro.online` |
| **Monitoring** | Prometheus + Grafana (kube-prometheus-stack) | Metrics from pods |
| **Traffic** | NGINX Ingress Controller | Routes HTTP→HTTPS, terminates TLS |
| **Automation** | Makefile | Single-command deployment, scaling, debugging |

---

## 💡 Key Numbers to Remember

| Item | Value |
|---|---|
| App port | **4499** |
| Replicas | **3** |
| Node type | **t3.small** |
| Node scaling | **min 1 / desired 2 / max 4** |
| VPC CIDR | **10.0.0.0/16** |
| Domain | **www.checkmypro.online** |
| Registry | **ghcr.io/anuragstark/wisecow:latest** |
| AWS Region | **us-east-1** |

---

## ⚡ Full Architecture Flow

```
Code Push → GitHub Actions →
  Job 1: Build Docker image → Push to GHCR (ghcr.io/anuragstark/wisecow:latest)
  Job 2: AWS credentials → update kubeconfig → kubectl apply → rollout wait

Traffic: HTTPS → NGINX Ingress (TLS terminated, cert from Let's Encrypt)
       → ClusterIP Service (80 → 4499) → 3 Pods → cowsay+fortune response

Infra:  Terraform  (EKS + VPC + IAM)
Setup:  Ansible    (kubectl + helm + ingress + cert-manager + prometheus)
Local:  Makefile   (build, deploy, scale, debug, monitor, destroy)
```

---

## 🔥 Interview Questions & Answers

---

### 📦 Application

**Q: What does the application actually do?**
> "It's a simple bash HTTP server. `wisecow.sh` uses a named pipe (FIFO) and `netcat` to listen on port 4499. When a request comes in, it runs `fortune` to get a random quote, passes it through `cowsay` to create ASCII art, wraps it in HTML, and sends back an HTTP 200 response."

**Q: What is a FIFO/named pipe in wisecow.sh?**
> "`mkfifo response` creates a named pipe — a special file used to pass data between processes without a socket. It passes the HTTP response from the handler function to `netcat` for sending."

---

### 🐳 Docker

**Q: Explain your Dockerfile.**
> "I use Ubuntu 22.04 as the base image. I install `fortune-mod`, `cowsay`, and `netcat-openbsd`. I add `/usr/games` to PATH because cowsay installs there on Ubuntu. I copy the shell script, make it executable, expose port 4499, and set it as the entrypoint."

**Q: Why Ubuntu instead of Alpine?**
> "The `fortune` and `cowsay` packages are easier to install on Ubuntu. Alpine would require more configuration for these utilities."

**Q: Where is the image stored?**
> "GitHub Container Registry — `ghcr.io/anuragstark/wisecow:latest`"

**Q: What is a Docker layer cache?**
> "Each `RUN`, `COPY`, `ADD` instruction creates a layer. Docker caches these. If nothing changed in that layer, it reuses the cache. To optimize, put things that change rarely (like `apt-get install`) before things that change often (like `COPY wisecow.sh`)."

**Q: What is the difference between `CMD` and `ENTRYPOINT`?**
> - `ENTRYPOINT` — always runs, can't be overridden easily
> - `CMD` — default arguments, can be overridden at runtime
> - "I used `CMD ["./wisecow.sh"]` so it can be overridden if needed for debugging."

**Q: What does `-it` flag mean in `docker run -it`?**
> "`-i` = interactive (keep STDIN open), `-t` = allocate pseudo-TTY terminal. Used for running bash inside a container."

---

### ☸️ Kubernetes

**Q: How many replicas do you run?**
> "3 replicas with a `RollingUpdate` strategy — `maxSurge: 1`, `maxUnavailable: 0`. This means deployments have zero downtime."

**Q: Why `maxUnavailable: 0`?**
> "Zero downtime — new pods must be Running before old ones stop. At any point during rollout, all 3 original pods are up until the new ones are ready."

**Q: Explain your health probes.**
> "I have all three probes:
> - **startupProbe**: Gives the container 60 seconds to start (12 checks × 5s interval). Prevents premature liveness failures.
> - **readinessProbe**: Checks every 10s. Pod only gets traffic when this passes.
> - **livenessProbe**: Starts after 60s, checks every 15s. Restarts the container if it's unhealthy."

**Q: Why startupProbe separately from livenessProbe?**
> "Without `startupProbe`, `livenessProbe` would kill the container before it has time to fully start — a startup race condition."

**Q: How do you handle resource limits?**
> "Each pod has CPU requests of 250m/limits of 500m, and memory requests of 128Mi/limits of 256Mi. This prevents any single pod from starving others."

**Q: What's the difference between Deployment, ReplicaSet, and Pod?**
> - **Pod** — smallest unit, runs your containers
> - **ReplicaSet** — ensures N pods are always running
> - **Deployment** — manages ReplicaSets, handles rolling updates & rollbacks. You never manage ReplicaSets directly.

**Q: What happens when a node goes down?**
> "K8s control plane detects the node is unhealthy via node heartbeats. It marks it `NotReady` and reschedules the pods onto healthy nodes automatically."

**Q: What is `kubectl rollout undo`?**
> "It rolls back a deployment to the previous ReplicaSet version. Used when a bad release goes out."

**Q: Why `imagePullPolicy: Always`?**
> "Forces Kubernetes to always pull the latest image from the registry, ensuring fresh deployments even if the tag (like `latest`) hasn't changed."

**Q: What is `fsGroup: 2000`?**
> "Sets the group ownership of mounted volumes so the process can read/write them."

**Q: What is `ghcr-secret`?**
> "A K8s `docker-registry` type secret with GHCR credentials so nodes can pull private images. Referenced in `imagePullSecrets` in the deployment spec."

---

## 🖥️ Replicas vs Nodes vs Node Scaling — Full Explanation

> Most beginners confuse these. They look similar but are completely different things.

---

### 🖥️ What is a Node?

A **Node** is a real physical/virtual machine (EC2 instance) that your pods run ON.

```
Node = A physical computer/server rented from AWS
Pod  = Your app container running ON that computer
```

In your project:
- Node type = `t3.small` = EC2 with **2 CPU cores + 2GB RAM**
- Terraform creates these EC2 machines as the EKS Node Group
- Your `wisecow` pods are scheduled and run **on top of these nodes**

```
AWS Cloud
  └── EKS Cluster (wisecow-cluster)
        ├── Node 1 (t3.small EC2 machine)   ← real server
        │     ├── wisecow Pod 1
        │     └── wisecow Pod 2
        └── Node 2 (t3.small EC2 machine)   ← real server
              └── wisecow Pod 3
```

**Q: Who manages nodes?**
> "AWS manages the EC2 machines. Kubernetes schedules which pods go on which node. You configure how many nodes exist via Terraform `scaling_config`."

---

### 🔁 What are Replicas?

**Replicas = how many identical copies of your app pod run simultaneously.**

```yaml
# in deployment.yaml
spec:
  replicas: 3
```

**Real-world analogy:**
> You open a restaurant and hire **3 waiters** (replicas). If one calls in sick (pod crashes), 2 are still working — zero downtime. K8s automatically hires a replacement to get back to 3.

In your project:
```
replicas: 3 = 3 identical wisecow pods always running
Pod crashes → K8s auto-starts a new one to maintain count of 3
Node crashes → K8s moves pods to remaining healthy nodes
```

**Why 3 replicas and not 1?**
- 1 pod: crashes → app is DOWN for ~30 seconds while K8s restarts it
- 3 pods: 1 crashes → 2 still serving → users see zero downtime

**Replicas are STATIC** — `replicas: 3` means always exactly 3. You or HPA must change this number to scale pods.

---

### 📊 What is Node Scaling? (min=1 / desired=2 / max=4)

This is the **AWS Auto Scaling Group** config for EC2 worker nodes — completely separate from pod replicas.

```hcl
# in terraform/main.tf
scaling_config {
  min_size     = 1   ← never go below 1 node
  desired_size = 2   ← start with 2 nodes (normal)
  max_size     = 4   ← can scale up to 4 nodes max
}
```

**Real-world analogy:**
> You run a call center. Normally you rent **2 office floors** (desired=2). During peak season you can unlock up to **4 floors** (max=4). Even on the quietest night you keep **1 floor** open (min=1) so you're never completely shut.

| Setting | Value | Meaning |
|---|---|---|
| `min_size = 1` | **1** | Always keep at least 1 EC2 machine running — even if zero traffic. K8s needs somewhere to run system pods. |
| `desired_size = 2` | **2** | Start with exactly 2 nodes. This is the normal operating count. |
| `max_size = 4` | **4** | Never spin up more than 4 nodes — prevents runaway AWS billing. |

**Who triggers node scaling?**
> **Cluster Autoscaler** — a pod in K8s that watches for:
> - Pods stuck as `Pending` (no room on existing nodes) → adds a new node (up to max=4)
> - Nodes mostly idle → removes a node (down to min=1)

---

### ❓ Is Node Scaling the same as HPA or VPA?

**No — they are 3 completely different scaling mechanisms:**

| Mechanism | Scales WHAT | Triggered By | In Your Project |
|---|---|---|---|
| **Replicas (static)** | Pods — fixed count | You manually | ✅ Yes — `replicas: 3` |
| **HPA** | Pods — auto-adds/removes | CPU/memory threshold | ❌ Not yet configured |
| **VPA** | Pod resource limits — resizes pods | Historical usage | ❌ Not yet configured |
| **Node Scaling (ASG)** | EC2 Nodes — adds/removes machines | Cluster Autoscaler | ✅ Yes — via Terraform |

---

### 📦 All 4 Scaling Types — Visual

```
┌──────────────────────────────────────────────┐
│  AWS Auto Scaling Group (min=1, desired=2, max=4) ← NODE SCALING (Terraform)
│                                              │
│  ┌────────────────┐   ┌────────────────┐     │
│  │ Node 1 t3.sm   │   │ Node 2 t3.sm   │     │
│  │  ┌──────────┐  │   │  ┌──────────┐  │     │
│  │  │ Pod 1 ✅ │  │   │  │ Pod 2 ✅ │  │     │  ← REPLICAS: 3 (deployment.yaml)
│  │  └──────────┘  │   │  └──────────┘  │     │
│  │  ┌──────────┐  │   │                │     │
│  │  │ Pod 3 ✅ │  │   │                │     │
│  │  └──────────┘  │   │                │     │
│  └────────────────┘   └────────────────┘     │
└──────────────────────────────────────────────┘

[CPU > 70%] → HPA triggers → Pod 4, Pod 5 added     ← HPA (not in project yet)
[Nodes full] → Cluster Autoscaler → Node 3 added    ← Node Scaling
[Pod uses 50MB but limit is 256MB] → VPA adjusts    ← VPA (not in project yet)
```

---

### 🎯 Simple One-Line Summary — Memorize This

| Concept | Simple Explanation |
|---|---|
| **Node** | A real EC2 machine (`t3.small` = 2 CPU, 2GB RAM) where pods live |
| **Replicas: 3** | Always keep exactly 3 copies of the app running |
| **min=1** | Even at zero traffic, never shut down all EC2 machines |
| **desired=2** | Default/normal — start with 2 EC2 machines |
| **max=4** | Hard ceiling — never create more than 4 EC2 machines |
| **HPA** | Auto-adds/removes PODS based on CPU/memory threshold |
| **VPA** | Auto-resizes CPU/RAM limits of pods based on actual usage |
| **Node Scaling (ASG)** | Auto-adds/removes EC2 MACHINES when pods can't be scheduled |

---

### 🔗 How They All Work Together (End-to-End)

```
Step 1: Terraform creates 2 EC2 nodes (desired=2)
Step 2: K8s schedules 3 wisecow pods across 2 nodes (replicas=3)
Step 3: Traffic spikes → CPU goes above 70%
Step 4: HPA (if set up) → adds Pod 4, Pod 5 automatically
Step 5: Nodes are now full → Pod 6 can't be scheduled → stays Pending
Step 6: Cluster Autoscaler sees Pending pod → adds Node 3 (within max=4)
Step 7: Pod 6 is scheduled on Node 3
Step 8: Traffic drops → HPA removes extra pods
Step 9: Nodes mostly idle → Cluster Autoscaler removes Node 3 (stays above min=1)

In YOUR project: Only Steps 1 & 2 work (no HPA configured yet)
Steps 4-9 would work after adding HPA + Cluster Autoscaler
```

---

### 🌐 Networking

**Q: How does traffic flow from internet to pod?**
> "`User → HTTPS (443) → NGINX Ingress → ClusterIP Service (port 80) → Pod port 4499`"

**Q: Why ClusterIP and not LoadBalancer for the app service?**
> "ClusterIP makes it internal-only. The NGINX Ingress Controller handles external traffic with its own LoadBalancer. This is the proper pattern — you don't expose every service directly."

**Q: Explain K8s networking — how does Pod-to-Pod communication work?**
> "Every pod gets its own IP. Pods communicate directly using those IPs. The CNI plugin (AWS VPC CNI in EKS) handles assigning real VPC IPs to pods, so pods can talk to each other like regular EC2 instances on the same VPC."

**Q: What is the difference between ClusterIP, NodePort, LoadBalancer?**
| Type | Access |
|---|---|
| ClusterIP | Internal only (within cluster) |
| NodePort | Exposes on each node's IP + a port |
| LoadBalancer | Creates an AWS ELB, public access |

---

### 🔒 TLS / cert-manager

**Q: How does TLS/HTTPS work?**
> "NGINX Ingress Controller handles incoming traffic. cert-manager automatically provisions a Let's Encrypt certificate using ACME HTTP-01 challenge. The certificate is stored as a K8s secret (`wisecow-tls`). Ingress is configured to force SSL redirect."

**Q: How does Let's Encrypt certificate get issued?**
> "cert-manager watches the Ingress. When it sees `cert-manager.io/cluster-issuer: letsencrypt-prod` annotation, it reads the `ClusterIssuer` and starts an ACME HTTP-01 challenge. Let's Encrypt sends a request to `www.checkmypro.online/.well-known/acme-challenge/...` — cert-manager creates a temporary pod to respond to it. Once validated, the certificate is stored in K8s secret `wisecow-tls`. cert-manager also auto-renews it before expiry."

**Q: What is `ClusterIssuer` vs `Issuer`?**
> "`ClusterIssuer` works across all namespaces. `Issuer` is namespace-scoped. I used `ClusterIssuer` so it can be reused for any app in any namespace."

**Q: What happens if cert-manager fails to renew the certificate?**
> "The site would show an SSL error after 90 days (Let's Encrypt certs expire in 90 days). cert-manager auto-renews at 60 days. To debug: `kubectl describe certificate wisecow-tls -n wisecow` and `kubectl describe clusterissuer letsencrypt-prod`."

---

### 🏗️ Terraform

**Q: What infrastructure did Terraform provision?**
> "VPC with CIDR `10.0.0.0/16`, 2 public subnets across 2 AZs, Internet Gateway, Route Table, Security Group (port 443 open), EKS cluster, and EKS Node Group with `t3.small` instances (min 1, max 4, desired 2)."

**Q: What are the 2 IAM roles and why?**
> "Two roles:
> 1. **`eks-cluster-role`** — For the EKS **control plane**. Trusted by `eks.amazonaws.com`. Has `AmazonEKSClusterPolicy` + `AmazonEKSServicePolicy`
> 2. **`eks-node-role`** — For the **worker nodes (EC2)**. Trusted by `ec2.amazonaws.com`. Has 3 policies:
>    - `AmazonEKSWorkerNodePolicy` — lets nodes join the cluster
>    - `AmazonEKS_CNI_Policy` — for pod networking (VPC CNI plugin)
>    - `AmazonEC2ContainerRegistryReadOnly` — so nodes can pull Docker images"

**Q: What does `AmazonEKS_CNI_Policy` do?**
> "Allows the VPC CNI plugin to assign private IPs from VPC to pods."

**Q: What is `terraform plan` vs `terraform apply`?**
> - `plan` — shows what **will** change, no actual changes made (dry run)
> - `apply` — actually creates/updates/destroys resources

**Q: What is `terraform destroy`?**
> "Destroys all resources managed by Terraform. Very dangerous in production."

**Q: What is state locking?**
> "When multiple people run Terraform simultaneously, state locking prevents conflicts. DynamoDB provides this when using S3 backend."

**Q: What does `?=` mean in Terraform variables?**
> "In the Makefile context, `?=` means the variable is set only if not already defined — allows runtime override like `make build IMAGE_TAG=v2.0`."

**Q: What are Terraform outputs used for?**
> "I output: `cluster_endpoint`, `cluster_name`, `cluster_security_group_id`, and `cluster_certificate_authority_data` — used by kubectl to authenticate with the cluster."

**Q: What is `~> 5.0` in provider version?**
> "Means 5.x — any patch version is allowed but not 6.0. Prevents breaking changes from major version upgrades."

---

### 🤖 Ansible

**Q: What does your Ansible playbook do?**
> "It runs on localhost and automates post-EKS-provisioning cluster setup: installs `kubectl` and `helm`, updates kubeconfig, installs NGINX Ingress Controller via Helm, installs cert-manager with CRDs, creates a `ClusterIssuer` for Let's Encrypt, creates the wisecow namespace, and installs kube-prometheus-stack for monitoring."

**Q: Why use Ansible instead of just shell scripts?**
> "Ansible is idempotent — you can run it multiple times without side effects. It also provides better error handling, retries, and conditions. The `kubernetes.core` module gives native K8s resource management."

**Q: What does Ansible do that Terraform doesn't?**
> "Terraform provisions the infrastructure (EKS cluster, VPC, nodes). Ansible configures what runs *inside* the cluster — installs Helm charts, creates K8s objects, configures tools. They work at different layers."

---

### ⚙️ CI/CD (GitHub Actions)

**Q: Explain your CI/CD pipeline.**
> "GitHub Actions workflow has two jobs:
> 1. **build-and-push**: Triggered on push to `main` or `develop`. Logs into GHCR using `GITHUB_TOKEN`, builds the Docker image, and pushes it with tags (branch name, PR ref, commit SHA, and `latest` for main).
> 2. **deploy**: Only runs on `main` branch, after build succeeds. Configures AWS credentials from secrets, updates kubeconfig for EKS, then `kubectl apply`s all manifests and waits for rollout."

**Q: What is `needs` in GitHub Actions?**
> "It defines job dependencies. My `deploy` job has `needs: build-and-push` — so deploy only runs after build succeeds."

**Q: What is `GITHUB_TOKEN`?**
> "An auto-generated token GitHub injects into every workflow run. Has permissions to the repo. I use it to login to GHCR — no manual secret needed."

**Q: How do you store secrets in GitHub Actions?**
> "AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) are stored as GitHub repository secrets. The GHCR login uses the auto-provided `GITHUB_TOKEN`."

**Q: What triggers your pipeline?**
> "Push to `main` or `develop` triggers build+push. Deploy only runs on push to `main`."

**Q: Why is the workflow file named `.disabled`?**
> "It was temporarily disabled during infrastructure setup/debugging to avoid auto-deployments while the cluster was still being configured."

---

### 📊 Monitoring

**Q: How did you set up monitoring?**
> "I installed `kube-prometheus-stack` using Helm via Ansible. The Deployment manifest has Prometheus annotations (`prometheus.io/scrape: true`, `prometheus.io/port: 4499`) so Prometheus auto-discovers and scrapes the pods."

---

### 🛠️ Makefile

**Q: What is a Makefile and why use one?**
> "A Makefile is an automation tool that groups complex shell commands under simple shortcut names called targets. Instead of typing 5 long commands, I just run `make deploy`. It gives dependency chaining, self-documentation via `make help`, and overridable variables."

**Q: What does `make deploy` do end to end?**
> "It chains 4 targets in order:
> 1. `terraform-apply` — provisions EKS cluster on AWS
> 2. `kubeconfig` — connects kubectl to the new cluster
> 3. `setup-cluster` — runs Ansible to install ingress, cert-manager, prometheus
> 4. `deploy-app` — applies all K8s manifests
> Then runs `health-check` automatically."

**Q: What is `.PHONY`?**
> "`.PHONY` tells Make these are command targets, not file names. Without it, if a file named `deploy` existed in the folder, Make would skip the target thinking it's already built."

**Q: How does `make scale` work?**
> "`make scale REPLICAS=5` runs `kubectl scale deployment wisecow-deployment --replicas=5 -n wisecow`. The `REPLICAS` variable is passed at runtime — a clean way to scale without editing YAML files."

#### All Makefile Targets

| Command | What It Does |
|---|---|
| `make help` | Prints all targets with descriptions |
| `make build` | `docker build -t ghcr.io/anuragstark/wisecow:latest .` |
| `make push` | `docker push` to GHCR registry |
| `make terraform-init` | `terraform init` |
| `make terraform-plan` | Dry run — shows what will change |
| `make terraform-apply` | Provisions AWS infra |
| `make terraform-destroy` | Tears down all AWS infra |
| `make kubeconfig` | `aws eks update-kubeconfig` |
| `make setup-cluster` | Runs Ansible playbook |
| `make deploy-app` | `kubectl apply` all K8s manifests |
| **`make deploy`** | **Full pipeline: infra + kubeconfig + ansible + kubectl** |
| `make scale REPLICAS=5` | Scales deployment to N replicas |
| `make restart` | Zero-downtime restart via rollout restart |
| `make logs` | Live log streaming |
| `make status` | Shows pods, services, ingress |
| `make debug` | Pods + events + logs all at once |
| `make health-check` | Runs health-check.sh |
| `make monitor` | Runs monitor.sh |
| `make get-url` | Gets LoadBalancer hostname |
| `make test` | curl hits the LoadBalancer URL |
| `make install-tools` | Installs kubectl, helm, terraform |
| `make clean` | Runs cleanup.sh |

---

### 🌐 AWS / EKS

**Q: What is the EKS control plane vs data plane?**
> - **Control plane** — AWS-managed (API server, etcd, scheduler). You don't see these nodes.
> - **Data plane** — Your worker nodes (EC2 `t3.small`). This is where pods run.

**Q: What is `aws eks update-kubeconfig`?**
> "Updates your local `~/.kube/config` file with the EKS cluster credentials so `kubectl` can connect to it."

**Q: What is a VPC and why did you create one?**
> "Virtual Private Cloud — isolated network in AWS. I created it with CIDR `10.0.0.0/16`. The EKS cluster and nodes live inside this VPC."

---

## 🚨 Tricky "Trap" Questions

| Question | Answer |
|---|---|
| Your CI/CD file is `.disabled` — is your pipeline broken? | "Temporarily disabled during cluster setup. In production I'd use environment-level deployment gates." |
| You run containers as root — isn't that a security risk? | "Yes, it's noted in the code as temporary for debugging. In production I'd run as non-root UID 1000." |
| Why `imagePullPolicy: Always` — isn't that slow? | "Ensures latest image is always pulled. Trade-off between speed and freshness. In production I'd use immutable tags instead of `latest`." |
| What if cert-manager fails? | "Site shows SSL error after 90 days. cert-manager auto-renews at 60 days. Debug with `kubectl describe certificate wisecow-tls -n wisecow`." |
| Terraform state is local — what's the problem? | "In a team, two people running terraform simultaneously causes state corruption. Fix: S3 backend + DynamoDB locking." |

---

## 💬 Behavioral Questions

**Q: What was the hardest part of this project?**
> *"Getting the health probes right. The app takes time to start, and the liveness probe was killing the container before it was ready. I solved it by adding a `startupProbe` to give the app 60 seconds to initialize before liveness checks began."*

**Q: How did you debug issues?**
> *"Mainly `kubectl logs -l app=wisecow -n wisecow` and `kubectl describe pod <pod-name> -n wisecow`. For the ingress I checked `kubectl get events -n wisecow` to see cert-manager challenge status."*

**Q: Why EKS over ECS or EC2 directly?**
> *"EKS gives me industry-standard Kubernetes, which is portable — the same manifests work on any cloud. ECS is AWS-specific. EC2 directly would require manual scaling and management."*

**Q: How would you improve this project?**
> - Private subnets for worker nodes (better security)
> - Terraform remote state in S3 + DynamoDB
> - Horizontal Pod Autoscaler (HPA) based on CPU
> - Image vulnerability scanning in CI/CD
> - RBAC for Kubernetes
> - Multi-environment setup (dev/staging/prod)
> - Immutable image tags instead of `latest`

---

## 📋 Quick kubectl Commands

```bash
# Check pods
kubectl get pods -n wisecow

# Check logs (live)
kubectl logs -f deployment/wisecow-deployment -n wisecow

# Logs from all pods with label
kubectl logs -l app=wisecow -n wisecow --tail=50

# Describe a pod (for debugging events)
kubectl describe pod <pod-name> -n wisecow

# Check deployment rollout status
kubectl rollout status deployment/wisecow-deployment -n wisecow

# Rollback to previous version
kubectl rollout undo deployment/wisecow-deployment -n wisecow

# Scale manually
kubectl scale deployment wisecow-deployment --replicas=5 -n wisecow

# Check certificate status
kubectl describe certificate wisecow-tls -n wisecow

# Check all resources in namespace
kubectl get pods,svc,ingress -n wisecow

# Check events (sorted by time)
kubectl get events -n wisecow --sort-by='.lastTimestamp'

# Connect kubectl to EKS
aws eks update-kubeconfig --region us-east-1 --name wisecow-cluster
```

---

## ✅ Final Checklist

- [ ] What does `wisecow.sh` do line by line?
- [ ] How does traffic get from internet → pod?
- [ ] Why 3 replicas with `maxUnavailable: 0`?
- [ ] What are the 2 IAM roles and why are they separate?
- [ ] How does TLS certificate get issued automatically?
- [ ] What does Ansible do that Terraform doesn't?
- [ ] How does CI/CD pipeline work step by step?
- [ ] How does GHCR image pull work in K8s?
- [ ] What does `make deploy` do end to end?
- [ ] How would you improve this project?

---

## 🎤 One-Line Summary (For Introduction)

> *"Wisecow is a DevOps project where I containerized a bash application using Docker, deployed it on AWS EKS provisioned via Terraform, automated cluster configuration with Ansible, set up TLS with cert-manager and Let's Encrypt, added Prometheus/Grafana monitoring, built a full CI/CD pipeline using GitHub Actions, and created a Makefile for single-command deployment lifecycle management."*

---

---

## 📁 Scripts — Deep Explanation (`scripts/` folder)

Your project has **4 utility scripts**. Interviewers may ask about them since Makefile calls them.

---

### 🔴 `scripts/deploy.sh` — Full Deployment Script

**Q: What does `deploy.sh` do?**
> "It's an alternative to `make deploy`. It:
> 1. Checks all required tools are installed (`aws`, `kubectl`, `helm`, `terraform`)
> 2. Runs `terraform init → plan → apply`
> 3. Runs `aws eks update-kubeconfig`
> 4. Runs Ansible playbook
> 5. Waits for NGINX ingress controller pod to be `Ready` (`kubectl wait --for=condition=ready`)
> 6. Applies all K8s manifests
> 7. Waits for deployment (`kubectl wait --for=condition=available --timeout=300s`)
> 8. Prints the LoadBalancer URL"

**Q: What is `set -e` at the top of the script?**
> "It means **exit immediately if any command fails**. If `terraform apply` fails, the script stops instead of continuing and causing cascading errors."

**Q: What is `kubectl wait`?**
> "It blocks the script until a condition is met. I use it to wait for the ingress controller pod to be `ready` before deploying the app — so there's no race condition where ingress isn't ready when manifests are applied."

---

### 🟢 `scripts/health-check.sh` — Health Check Script

**Q: What does `health-check.sh` check?**
> "It does a comprehensive 8-step health check:
> 1. ✅ Cluster connectivity (`kubectl cluster-info`)
> 2. ✅ Namespace exists
> 3. ✅ Deployment exists
> 4. ✅ Ready replicas == Desired replicas (using `jsonpath`)
> 5. ✅ All pods are in Running phase
> 6. ✅ Service exists
> 7. ✅ Ingress exists + NGINX ingress controller is running
> 8. ✅ TLS certificate is Ready
> 9. ✅ Hits LoadBalancer URL with `curl` and checks HTTP 200/301/302
> 10. ✅ Resource usage via `kubectl top pods`
> Exits with code `0` (healthy) or `1` (unhealthy) — useful for CI/CD pipelines."

**Q: How does it check if replicas are ready?**
```bash
READY=$(kubectl get deployment wisecow-deployment -n wisecow -o jsonpath='{.status.readyReplicas}')
DESIRED=$(kubectl get deployment wisecow-deployment -n wisecow -o jsonpath='{.spec.replicas}')
# Then compares READY == DESIRED
```
> "Uses `jsonpath` to extract specific fields from K8s JSON output instead of parsing the full output."

**Q: What is `jsonpath`?**
> "A query language to extract values from JSON. Like XPath for XML. `{.status.readyReplicas}` pulls only that field from the deployment object."

---

### 🔵 `scripts/monitor.sh` — Monitoring Script

**Q: What does `monitor.sh` show?**
> "It prints a full dashboard in one shot:
> - Deployment status
> - Pod status with `-o wide` (shows which node each pod is on)
> - Service status
> - Ingress status
> - Certificate status
> - Recent 10 events (sorted by timestamp)
> - Resource usage (`kubectl top pods`) — shows live CPU/memory per pod
> - LoadBalancer URL
> - Running pods vs total pods count"

---

### 🟡 `scripts/cleanup.sh` — Cleanup Script

**Q: What does `cleanup.sh` do? What order does it follow?**
> "It deletes resources in the correct **reverse dependency order**:
> 1. Delete K8s manifests (ingress → service → deployment → cluster-issuer) with `--ignore-not-found` so it doesn't fail if already gone
> 2. Helm uninstall cert-manager and ingress-nginx
> 3. Delete namespaces (`wisecow`, `cert-manager`, `ingress-nginx`)
> 4. `terraform destroy -auto-approve` to tear down AWS infra"

**Q: Why `--ignore-not-found` flag?**
> "Makes the delete command idempotent — it won't error if the resource was already deleted. Safe to run multiple times."

---

## 🗂️ ConfigMap (`k8s/configmap.yaml`)

**Q: Your configmap.yaml is empty — why?**
> "It's a placeholder for future use. ConfigMaps store non-sensitive config data (like environment variables, config files) as K8s objects. I didn't need one here since the app only needs `PORT=4499` which is set directly in the deployment's `env` section."

**Q: When would you use a ConfigMap?**
> "If the app needed multiple environment variables, config files, or settings that change between environments (dev/staging/prod), I'd put them in a ConfigMap and mount it into the pod — so I don't need to rebuild the Docker image for config changes."

---

## 📊 HPA — Horizontal Pod Autoscaler

**Q: Does your project have HPA?**
> "Not yet configured in YAML, but the README documents how to set it up:
> ```bash
> kubectl autoscale deployment wisecow-deployment --cpu-percent=70 --min=3 --max=10 -n wisecow
> ```
> This auto-scales pods when CPU crosses 70%, between 3–10 replicas. It's one of the improvements I'd make."

**Q: What is VPA?**
> "Vertical Pod Autoscaler — automatically adjusts CPU/memory **requests and limits** for pods based on actual usage. HPA scales out (more pods), VPA scales up (bigger pods). You typically don't use both together on the same deployment."

---

## 🐛 All Pod Error States — Must Know

| Status | What It Means | How to Fix |
|---|---|---|
| `CrashLoopBackOff` | Container keeps crashing and restarting | `kubectl logs <pod>` to see crash reason |
| `ImagePullBackOff` | Can't pull the Docker image | Check registry, `ghcr-secret`, image name |
| `Pending` | Pod can't be scheduled onto a node | Node resources full, check `kubectl describe pod` |
| `OOMKilled` | Container exceeded memory limit | Increase memory limit in deployment |
| `Error` | Container exited with non-zero code | Check logs |
| `Terminating` | Pod is being deleted but stuck | `kubectl delete pod <name> --force --grace-period=0` |
| `ContainerCreating` | Pulling image / mounting volumes | Usually temporary, wait or check events |

---

## 🔧 Advanced Debug Commands

```bash
# Execute INTO a running pod (like SSH)
kubectl exec -it <pod-name> -n wisecow -- /bin/bash

# Port-forward to test pod directly (bypass ingress/service)
kubectl port-forward pod/<pod-name> -n wisecow 4499:4499
# Then: curl http://localhost:4499

# Port-forward via service
kubectl port-forward svc/wisecow-service -n wisecow 8080:80

# Check what node a pod is on
kubectl get pods -n wisecow -o wide

# Check all resources across ALL namespaces
kubectl get all --all-namespaces

# Get all LoadBalancer services across namespaces
kubectl get svc --all-namespaces | grep LoadBalancer

# Check endpoints (is service pointing to pods correctly?)
kubectl get endpoints -n wisecow

# Check network connectivity between pods
kubectl exec -it <pod> -n wisecow -- nc -zv wisecow-service 80

# Watch pods in real-time
kubectl get pods -n wisecow --watch

# Watch events in real-time
kubectl get events -n wisecow --watch

# Test TLS certificate
openssl s_client -connect www.checkmypro.online:443 -servername www.checkmypro.online

# Check DNS
dig www.checkmypro.online +short
nslookup www.checkmypro.online
```

---

## 🔐 Security — What I Know & What I'd Improve

### Current Security Setup
- TLS enforced (HTTP redirects to HTTPS)
- `capabilities: drop: ["ALL"]` — drops all Linux kernel capabilities from container
- `fsGroup: 2000` — volume file ownership

### Known Issues (Be Honest!)
- Running as `root` (`runAsUser: 0`) — noted as temporary for debugging
- Terraform state stored locally (should be S3 + DynamoDB)
- `imagePullPolicy: Always` with `latest` tag (should use immutable SHA tags)

### What I'd Add
- `runAsNonRoot: true` with a dedicated user
- Network Policies to restrict pod-to-pod traffic
- RBAC roles for least privilege
- Image scanning in CI/CD (`trivy` or `snyk`)
- Secrets management with AWS Secrets Manager or HashiCorp Vault
- Separate namespaces per environment

---

## 📐 Full Project File Structure

```
wisecow/
├── 📄 Dockerfile              # Container definition (Ubuntu 22.04, port 4499)
├── 📄 docker-compose.yml      # Local development (port 4499, healthcheck)
├── 📄 Makefile                # All automation targets
├── 📄 wisecow.sh              # Main app — bash HTTP server using netcat + FIFO
├── 📁 k8s/
│   ├── deployment.yaml        # 3 replicas, rolling update, all 3 probes, resources
│   ├── service.yaml           # ClusterIP: port 80 → targetPort 4499
│   ├── ingress.yaml           # NGINX ingress, force HTTPS, cert-manager TLS
│   ├── cluster-issuer.yaml    # Let's Encrypt ACME HTTP-01 solver
│   └── configmap.yaml         # Empty placeholder
├── 📁 terraform/
│   ├── main.tf                # VPC, subnets, IGW, route table, SG, EKS cluster+nodes
│   ├── iam.tf                 # 2 IAM roles: cluster role + node role with policies
│   ├── variable.tf            # aws_region, cluster_name, node_group_name
│   └── output.tf              # cluster_endpoint, name, security_group_id, cert_data
├── 📁 ansible/
│   └── setup-cluster.yaml     # kubectl, helm, nginx-ingress, cert-manager, prometheus
├── 📁 scripts/
│   ├── deploy.sh              # Full deploy: checks tools → terraform → ansible → kubectl
│   ├── health-check.sh        # 10-step health check, exits 0/1 for CI/CD
│   ├── monitor.sh             # Full status dashboard: pods, svc, ingress, certs, events
│   └── cleanup.sh             # Reverse teardown: k8s → helm → namespaces → terraform
└── 📁 .github/workflows/
    └── ci-cd.yaml.disabled    # Build+push to GHCR, deploy to EKS on main push
```

---

## 🔄 Complete Deployment Workflow (Step by Step)

```
From Zero to Running App:

1. terraform init          → Downloads AWS provider plugin
2. terraform plan          → Shows what will be created (dry run)
3. terraform apply         → Creates: VPC → Subnets → IGW → RT → SG → EKS → Nodes → IAM
4. aws eks update-kubeconfig → Adds cluster credentials to ~/.kube/config
5. ansible-playbook        → Installs: kubectl → helm → nginx-ingress → cert-manager
                          → Creates ClusterIssuer → Creates wisecow namespace → prometheus
6. kubectl apply deployment.yaml → Creates: Namespace + Deployment (3 pods)
7. kubectl apply service.yaml    → Creates: ClusterIP service (80 → 4499)
8. kubectl apply cluster-issuer.yaml → Configures Let's Encrypt
9. kubectl apply ingress.yaml    → NGINX routes traffic, cert-manager issues TLS cert
10. DNS: Point domain → LoadBalancer hostname
11. HTTPS works! cert-manager auto-renews every 60 days
```

---

## ✅ Final Checklist

- [ ] What does `wisecow.sh` do line by line?
- [ ] How does traffic get from internet → pod?
- [ ] Why 3 replicas with `maxUnavailable: 0`?
- [ ] What are the 2 IAM roles and why are they separate?
- [ ] How does TLS certificate get issued automatically?
- [ ] What does Ansible do that Terraform doesn't?
- [ ] How does CI/CD pipeline work step by step?
- [ ] How does GHCR image pull work in K8s?
- [ ] What does `make deploy` do end to end?
- [ ] What do the 4 scripts do?
- [ ] What is `set -e`? What is `jsonpath`? What is `.PHONY`?
- [ ] What are CrashLoopBackOff and ImagePullBackOff?
- [ ] How would you improve this project?

---

## 🎤 One-Line Summary (For Introduction)

> *"Wisecow is a DevOps project where I containerized a bash application using Docker, deployed it on AWS EKS provisioned via Terraform, automated cluster configuration with Ansible, set up TLS with cert-manager and Let's Encrypt, added Prometheus/Grafana monitoring, built a full CI/CD pipeline using GitHub Actions, and created a Makefile + shell scripts for complete deployment lifecycle management."*

---

## 🐄 `wisecow.sh` — Complete Line-by-Line Explanation

---

### What is `fortune`?

`fortune` is a **Linux command-line program** that prints a random quote, joke, or saying every time you run it.

```bash
$ fortune
# Example output:
"The secret of getting ahead is getting started."
                -- Mark Twain
```

- Picks randomly from text files called **fortune cookies** stored in `/usr/share/games/fortunes/`
- A fun Unix tradition from the 1970s — used to display a random message on terminal login
- In your project: generates the **text content** the cow will speak

---

### What is `cowsay`?

`cowsay` is a **Linux program** that takes text as input and wraps it in an **ASCII art speech bubble** with a cow below it.

```
$ cowsay "Hello World"

 _____________
< Hello World >
 -------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

- `<pre>` tags in HTML preserve the spacing so ASCII art doesn't collapse
- Other animals available: `cowsay -f tux` = penguin, `cowsay -f dragon` = dragon
- In your project: wraps the `fortune` output in ASCII art

**Together:**
```bash
fortune | cowsay
# fortune generates quote → cowsay draws a cow saying it
```

---

### What are HTTP Headers?

When a browser gets a response, two parts are sent — **headers** (metadata) and **body** (content):

```
HTTP/1.1 200 OK              ← Status line: was it successful?
Content-Type: text/html      ← Header: what type of content?
Content-Length: 342          ← Header: how many bytes in body?
Connection: close            ← Header: close TCP after sending
                             ← Blank line (REQUIRED by HTTP spec)
<html>...</html>             ← Body: the actual content
```

| Part | What It Is | Analogy |
|---|---|---|
| **Status Line** | Success/Error code | Delivery status: ✅ or ❌ |
| **Headers** | Metadata about response | Envelope labels: "fragile", "urgent" |
| **Blank Line** | Mandatory separator | ----- |
| **Body** | Actual HTML/data | The letter inside |

**Headers vs Head vs `head` — they are DIFFERENT things:**

| Term | Meaning |
|---|---|
| **HTTP Headers** | Metadata sent with every HTTP request/response (Content-Type, Content-Length, etc.) |
| **`<head>` in HTML** | HTML tag holding page metadata (title, CSS links) — not visible on the page |
| **`head` command** | Linux command that shows the first N lines of a file (`head -10 file.txt`) |

**In `wisecow.sh`:**
```bash
HTTP/1.1 200 OK              ← "Request was fine"
Content-Type: text/html      ← "Expect HTML"
Content-Length: $content_length  ← "Body is N bytes"
Connection: close            ← "Close TCP after this"
```
Without correct headers, browsers don't know how to render the response.

---

### Why `/usr/games/` instead of default PATH?

**Default Linux PATH** includes: `/usr/bin`, `/bin`, `/usr/local/bin`

On **Ubuntu/Debian**, `cowsay` and `fortune` are classified as **"entertainment/game" programs** — installed to:
```
/usr/games/cowsay
/usr/games/fortune
```

This is a Debian convention separating "serious" tools from games/fun utilities.  
**Problem:** `/usr/games/` is NOT in default PATH → `cowsay` = "command not found!"

**Your Dockerfile fixes this:**
```dockerfile
ENV PATH="/usr/games:${PATH}"
```
Prepends `/usr/games` to PATH — now `cowsay` and `fortune` are found everywhere.

**Your `wisecow.sh` double-checks BOTH locations:**
```bash
if ! command -v cowsay >/dev/null 2>&1 && ! command -v /usr/games/cowsay >/dev/null 2>&1; then
    echo "cowsay is not installed"
    exit 1
fi
```
- First: checks default PATH via `command -v`
- Then: checks `/usr/games/cowsay` directly as fallback
- If NEITHER found → exits with error code 1 → K8s health probe would detect failure

---

### `wisecow.sh` — Line by Line

```bash
#!/usr/bin/env bash
```
**Shebang** — tells OS to run this with bash. `env bash` finds bash from PATH — more portable than `#!/bin/bash`.

```bash
SRVPORT=4499
RSPFILE=response
```
- `SRVPORT` — port the server listens on
- `RSPFILE` — name of the **named pipe (FIFO)** file used to tunnel data between processes

```bash
rm -f $RSPFILE
mkfifo $RSPFILE
```
- `rm -f` — removes old pipe file if it exists (prevents error on restart)
- `mkfifo` — creates a **named pipe**: a special file that acts like a real-time tunnel. Data written in one end comes out the other. No storage — it flows through.

---

**Function 1: `get_api()`**
```bash
get_api() {
    read line
    echo $line
}
```
- `read line` — reads ONE line from stdin (the incoming HTTP request, e.g., `GET / HTTP/1.1`)
- `echo $line` — logs it (not critical to functionality)

---

**Function 2: `handleRequest()`**
```bash
handleRequest() {
    get_api                        # Read/consume the incoming HTTP request line

    mod=`fortune`                  # Run fortune → random quote stored in $mod
    cow_output=`cowsay "$mod"`     # Pass quote to cowsay → ASCII art stored in $cow_output

    content="<html><body><pre>$cow_output</pre></body></html>"
    content_length=${#content}     # ${#var} = string length → used for Content-Length header

    cat <<EOF > $RSPFILE           # Write HTTP response into the named pipe
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: $content_length
Connection: close

$content
EOF
}
```

Key points:
- **Backticks `` `cmd` ``** = command substitution (same as `$(cmd)`)
- **`${#content}`** = length of the string in characters
- **`<<EOF ... EOF`** = heredoc — writes multi-line text without echo per line
- **`> $RSPFILE`** = writes the HTTP response INTO the named pipe

---

**Function 3: `prerequisites()`**
```bash
prerequisites() {
    if ! command -v cowsay >/dev/null 2>&1 && ! command -v /usr/games/cowsay >/dev/null 2>&1; then
        echo "cowsay is not installed"
        exit 1
    fi
    # same check for fortune...
}
```
- `command -v` — checks if program exists in PATH (returns 0=found, 1=not found)
- `>/dev/null 2>&1` — silences all output (stdout to /dev/null, stderr to stdout)
- If missing → `exit 1` → K8s startup/liveness probe registers failure → pod restarts

---

**Function 4: `main()` — The Server Loop**
```bash
main() {
    prerequisites
    echo "Wisdom served on port=$SRVPORT..."

    while [ 1 ]; do
        cat $RSPFILE | nc -lN $SRVPORT | handleRequest
        sleep 0.01
    done
}
```

**`while [ 1 ]`** — infinite loop (`1` is always true). Restarts `nc` for each new connection.

**The 3-part pipeline — most important line:**
```bash
cat $RSPFILE | nc -lN $SRVPORT | handleRequest
```

| Part | Role |
|---|---|
| `cat $RSPFILE` | Reads HTTP response from named pipe → sends to nc for delivery |
| `nc -lN $SRVPORT` | **netcat**: listens on port 4499, accepts ONE connection. Sends request to `handleRequest`, sends response back to client. `-N` = shutdown after EOF |
| `handleRequest` | Reads request, runs fortune+cowsay, builds HTTP response, writes it back into `$RSPFILE` |

**Request flow per connection:**
```
Browser connects to port 4499
       ↓
nc receives HTTP request → pipes to handleRequest
       ↓
handleRequest: fortune → cowsay → build HTML → write to FIFO pipe
       ↓
cat reads from FIFO → pipes back to nc
       ↓
nc sends HTTP response to browser
       ↓
Connection closes (Connection: close)
       ↓
sleep 0.01 → loop restarts → nc waits for next connection
```

**`sleep 0.01`** — 10ms pause prevents 100% CPU spinning in the tight loop.

---

### Key Interview Points for `wisecow.sh`

| Concept | What to Say |
|---|---|
| **Named pipe (FIFO)** | Special file for inter-process communication — flows in real time, no storage |
| **netcat (`nc`)** | Raw TCP utility used as a minimal HTTP server. `-lN` = listen, close after one connection |
| **Heredoc (`<<EOF`)** | Write multi-line string to file/pipe cleanly |
| **`${#var}`** | String length — used for `Content-Length` HTTP header |
| **`>/dev/null 2>&1`** | Silence all output |
| **Why `while [1]`?** | nc handles ONE request per iteration, loop restarts nc for the next request |
| **`sleep 0.01`** | Prevents CPU busy-loop |
| **`command -v`** | Checks if a program exists in PATH |
| **Why `/usr/games/`?** | Ubuntu installs cowsay/fortune there — not in default PATH |
| **Why `ENV PATH="/usr/games:${PATH}"`?** | Dockerfile fix to include /usr/games in PATH inside container |

---

## 🐳 Dockerfile — Complete Line-by-Line Explanation

---

### The Full File

```dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
ENV SRVPORT=4499
RUN apt-get update && apt-get install -y fortune-mod cowsay netcat-openbsd && rm -rf /var/lib/apt/lists/*
ENV PATH="/usr/games:${PATH}"
WORKDIR /app
COPY wisecow.sh /app/wisecow.sh
RUN chmod +x /app/wisecow.sh && ls -la /app/wisecow.sh
EXPOSE 4499
CMD ["./wisecow.sh"]
```

---

### Line by Line

**`FROM ubuntu:22.04`**
- Every Dockerfile MUST start with `FROM` — defines the **base image** (the OS)
- `ubuntu:22.04` = Ubuntu LTS (Long Term Support) — stable, supported until 2027
- **Why Ubuntu?** `cowsay` and `fortune` install cleanly. Alpine would be smaller but needs more manual config for these packages

---

**`ENV DEBIAN_FRONTEND=noninteractive`**
- `ENV` sets an **environment variable** inside the container
- Tells `apt-get` to **never ask interactive questions** (like "Do you want to continue? Y/n")
- Without this, `docker build` would **hang** waiting for user input during package install

---

**`ENV SRVPORT=4499`**
- Sets the port as an environment variable available inside the container
- `wisecow.sh` reads this value to know which port to listen on

---

**`RUN apt-get update && apt-get install -y fortune-mod cowsay netcat-openbsd && rm -rf /var/lib/apt/lists/*`**
- `RUN` — executes a command **during `docker build`** (not at runtime)
- `apt-get update` — refreshes the package list from Ubuntu repositories
- `apt-get install -y` — installs packages; `-y` = auto-yes to all prompts
- **`fortune-mod`** — gives the `fortune` command  
- **`cowsay`** — gives the `cowsay` command  
- **`netcat-openbsd`** — gives the `nc` command used as HTTP server in wisecow.sh
- `&& rm -rf /var/lib/apt/lists/*` — **deletes apt cache** after install → reduces image size
- `&&` chains commands — if `apt-get update` fails, the whole `RUN` stops immediately

> **Why one `RUN` instead of separate?** Each `RUN` = a new Docker layer. Combining them into one means only one layer is created, and the cleanup (`rm -rf`) actually reduces the layer size. If split, `rm -rf` in a separate layer can't shrink a previous layer.

---

**`ENV PATH="/usr/games:${PATH}"`**
- Ubuntu installs `cowsay` and `fortune` in `/usr/games/` — NOT in default PATH
- **Prepends** `/usr/games` to existing PATH → now `cowsay` and `fortune` work without full path
- `${PATH}` = current PATH value — preserved and appended after `/usr/games:`

---

**`WORKDIR /app`**
- Sets the **working directory** for all following instructions
- Creates `/app` if it doesn't exist
- All `COPY`, `RUN`, `CMD` run relative to `/app`
- Equivalent to: `mkdir -p /app && cd /app`

---

**`COPY wisecow.sh /app/wisecow.sh`**
- `COPY` — copies a file **from your host machine** → **into the container image**
- Left side: source file on your laptop
- Right side: destination path inside the container

---

**`RUN chmod +x /app/wisecow.sh && ls -la /app/wisecow.sh`**
- `chmod +x` — makes the script **executable** (without this the OS refuses to run it)
- `ls -la` — verifies the file exists and permissions are correct (sanity check during build — you'll see the output in `docker build` logs)

---

**`EXPOSE 4499`**
- ⚠️ **Does NOT publish the port** — it's just **documentation metadata**
- Tells other developers/tools "this container expects traffic on 4499"
- Actual port mapping happens at:
  - Runtime: `docker run -p 4499:4499`
  - Kubernetes: `containerPort: 4499` in deployment.yaml

---

**`CMD ["./wisecow.sh"]`**
- The **default command** to run when the container starts
- Uses **exec form** (JSON array) — runs directly as PID 1, NOT wrapped in a shell
- Since `WORKDIR` is `/app`, this runs `/app/wisecow.sh`
- Can be overridden: `docker run myimage bash` → starts bash instead

---

### 🧠 Key Interview Q&A on Dockerfile

**Q: Difference between `RUN`, `CMD`, `ENTRYPOINT`?**
| Instruction | When It Runs | Purpose |
|---|---|---|
| `RUN` | During `docker build` | Install packages, set up environment |
| `CMD` | When container starts | Default command (can be overridden) |
| `ENTRYPOINT` | When container starts | Main process (harder to override) |

**Q: `COPY` vs `ADD`?**
> "`COPY` copies local files. `ADD` also supports URLs and auto-extracts `.tar.gz`. Best practice: always use `COPY` unless you specifically need `ADD`'s extra features."

**Q: Why `rm -rf /var/lib/apt/lists/*`?**
> "Deletes the apt package index cache after installation. Reduces final image size — no need to keep the package list after packages are installed."

**Q: Why exec form `CMD ["./wisecow.sh"]` not shell form `CMD ./wisecow.sh`?**
> "Exec form runs the process as **PID 1** — it receives OS signals like SIGTERM for graceful shutdown. Shell form wraps it in `/bin/sh -c` which becomes PID 1, and your actual script won't receive signals — it won't shut down cleanly."

**Q: What is a Docker layer?**
> "Every `FROM`, `RUN`, `COPY`, `ENV` creates a new layer — a filesystem diff. Layers are **cached**: if nothing changed, Docker reuses the cache. That's why you put frequently changing instructions (`COPY wisecow.sh`) AFTER rarely changing ones (`apt-get install`) — for faster rebuilds."

**Q: What is Docker build context?**
> "The `.` in `docker build -t myimage .` — the directory Docker sends to the daemon. Everything in that folder is available during build. Use `.dockerignore` to exclude large files like `node_modules`, `.git`, etc."

**Q: What does `DEBIAN_FRONTEND=noninteractive` do?**
> "Prevents apt from asking timezone or confirmation questions during build. Without it, `docker build` would hang waiting for human input."

**Q: What does `EXPOSE` actually do?**
> "Nothing at runtime — pure documentation. The real port mapping is `docker run -p 4499:4499` or Kubernetes `containerPort: 4499`."

---

### Build vs Run — What Happens When

```
docker build:                       docker run:
─────────────────────────           ─────────────────────
FROM ubuntu:22.04       ✅          Container starts with image
ENV DEBIAN_FRONTEND=... ✅
ENV SRVPORT=4499        ✅          SRVPORT=4499 available
RUN apt-get install...  ✅          (already installed)
ENV PATH=/usr/games:... ✅          PATH includes /usr/games
WORKDIR /app            ✅          cwd = /app
COPY wisecow.sh         ✅          (file already in image)
RUN chmod +x ...        ✅          (already executable)
EXPOSE 4499             ✅          (just metadata)
CMD ["./wisecow.sh"]    (stored)    → ./wisecow.sh runs NOW
```

---

## ☸️ Kubernetes Files — Complete Line-by-Line Explanation (`k8s/` folder)

There are **5 files** in `k8s/`:
1. `deployment.yaml` — runs & manages the app pods
2. `service.yaml` — internal networking to reach pods
3. `ingress.yaml` — external traffic routing + TLS
4. `cluster-issuer.yaml` — Let's Encrypt TLS certificate config
5. `configmap.yaml` — empty placeholder

---

## 📄 1. `deployment.yaml` — The Most Important File

```yaml
apiVersion: apps/v1
kind: Deployment
```
- `apiVersion: apps/v1` — which Kubernetes API group handles this resource. Deployments belong to the `apps` group, version `v1`
- `kind: Deployment` — the type of K8s object being created

---

```yaml
metadata:
  name: wisecow-deployment
  namespace: wisecow
  labels:
    app: wisecow
```
- `metadata.name` — the name of this deployment — used in `kubectl get deployment wisecow-deployment`
- `namespace: wisecow` — puts this resource in the `wisecow` namespace (isolation from other apps)
- `labels` — key-value tags attached to the deployment object for filtering/selection

---

```yaml
spec:
  replicas: 3
```
- Run **3 identical pod copies** at all times
- If one pod crashes, K8s automatically starts a replacement

---

```yaml
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```
- `RollingUpdate` — update pods gradually, not all at once (zero-downtime deploys)
- `maxSurge: 1` — during update, **1 extra pod** can be created above the 3 replica count (so 4 pods temporarily)
- `maxUnavailable: 0` — **zero pods** can be unavailable during update — all 3 must stay up until new ones are ready
- Result: new pod starts → becomes ready → old pod stops → repeat

---

```yaml
  selector:
    matchLabels:
      app: wisecow
```
- Tells the Deployment **which pods it owns** — pods with label `app: wisecow`
- Must match the `template.metadata.labels` below — this is how Deployment and pods are linked

---

```yaml
  template:
    metadata:
      labels:
        app: wisecow
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "4499"
```
- `template` — the pod blueprint (every pod created follows this template)
- `labels: app: wisecow` — pods get this label — must match `selector.matchLabels`
- `annotations` — non-selecting metadata. These two tell **Prometheus to auto-discover and scrape metrics** from port 4499 of each pod

---

```yaml
    spec:
      imagePullSecrets:
        - name: ghcr-secret
```
- `imagePullSecrets` — K8s secret containing GHCR credentials
- Before pulling the Docker image, K8s uses this secret to authenticate with `ghcr.io`
- The secret type is `docker-registry` and was created manually: `kubectl create secret docker-registry ghcr-secret ...`

---

```yaml
      containers:
        - name: wisecow
          image: ghcr.io/anuragstark/wisecow:latest
          imagePullPolicy: Always
```
- `name: wisecow` — name of the container inside the pod
- `image` — the Docker image to run (from GitHub Container Registry)
- `imagePullPolicy: Always` — always pull fresh image on every pod start, even if it's already cached (ensures `latest` tag is actually latest)

---

```yaml
          command: ["/bin/bash", "-c", "cd /app && exec ./wisecow.sh"]
```
- Overrides the Dockerfile `CMD`
- `cd /app` — ensures working directory is correct
- `exec ./wisecow.sh` — **`exec` replaces the shell process with wisecow.sh** — so wisecow.sh becomes PID 1 and receives OS signals (SIGTERM for graceful shutdown)

---

```yaml
          ports:
            - containerPort: 4499
              name: http
```
- Documents that this container listens on port 4499
- `name: http` — gives the port a name so it can be referenced by name instead of number

---

```yaml
          env:
            - name: PORT
              value: "4499"
```
- Injects environment variable `PORT=4499` into the container
- The app can read this via `$PORT` environment variable

---

```yaml
          resources:
            requests:
              memory: "128Mi"
              cpu: "250m"
            limits:
              memory: "256Mi"
              cpu: "500m"
```
- `requests` — **minimum guaranteed** resources. K8s uses this to schedule the pod on a node that has enough
- `limits` — **maximum allowed**. If container exceeds this → CPU is throttled, memory → OOMKilled
- `250m` CPU = 250 millicores = 0.25 of one CPU core
- `128Mi` = 128 Mebibytes of RAM

**Q: What happens if a pod exceeds memory limit?**
> "It gets `OOMKilled` (Out Of Memory Killed) — K8s terminates the container and restarts it."

---

```yaml
          startupProbe:
            httpGet:
              path: /
              port: 4499
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 5
            failureThreshold: 12
            successThreshold: 1
```
- **startupProbe** — gives the container time to start before liveness kicks in
- `httpGet` — sends HTTP GET to `http://pod-ip:4499/` to check if app is responding
- `initialDelaySeconds: 10` — waits 10s after container start before first check
- `periodSeconds: 5` — checks every 5 seconds
- `failureThreshold: 12` — allows 12 failures (12 × 5s = 60 seconds total startup time)
- Once startupProbe succeeds → liveness and readiness probes take over

---

```yaml
          readinessProbe:
            httpGet:
              path: /
              port: 4499
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
            successThreshold: 1
```
- **readinessProbe** — is the pod **ready to receive traffic**?
- If this fails → pod is removed from the Service's endpoints (no traffic sent to it)
- Checks every 10s, fails after 3 consecutive failures
- Allows pod to temporarily stop getting traffic without being killed

---

```yaml
          livenessProbe:
            httpGet:
              path: /
              port: 4499
            initialDelaySeconds: 60
            periodSeconds: 15
            timeoutSeconds: 5
            failureThreshold: 3
            successThreshold: 1
```
- **livenessProbe** — is the pod **still alive and healthy**?
- If this fails → K8s **kills and restarts** the container
- `initialDelaySeconds: 60` — waits 60s before first check (gives app time to fully start after startupProbe)
- Restarts pod after 3 consecutive failures (3 × 15s = 45 seconds)

**The 3 Probes Summary:**
| Probe | Fails → | Purpose |
|---|---|---|
| `startupProbe` | Nothing (retries up to 60s) | Give app time to boot |
| `readinessProbe` | Pod removed from Service | Stop sending traffic to unhealthy pod |
| `livenessProbe` | Pod restarted | Recover from deadlocks/hangs |

---

```yaml
          securityContext:
            runAsNonRoot: false
            runAsUser: 0
            capabilities:
              drop: ["ALL"]
```
- `runAsUser: 0` — runs as **root** (UID 0) — noted as temporary for debugging
- `runAsNonRoot: false` — disables the non-root enforcement
- `capabilities: drop: ["ALL"]` — removes all Linux kernel capabilities from the container even though it runs as root — limits what root can do

---

```yaml
      restartPolicy: Always
      securityContext:
        fsGroup: 2000
```
- `restartPolicy: Always` — always restart containers if they exit (default for Deployments)
- `fsGroup: 2000` — any mounted volumes will be owned by group ID 2000 — allows the process to read/write volume files

---

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: wisecow
```
- `---` separator — allows multiple resources in one YAML file
- Creates the `wisecow` namespace
- All app resources (deployment, service, ingress) live in this namespace

---

## 📄 2. `service.yaml` — Internal Networking

```yaml
apiVersion: v1
kind: Service
metadata:
  name: wisecow-service
  namespace: wisecow
  labels:
    app: wisecow
```
- `kind: Service` — a K8s networking object that provides a stable endpoint to reach pods
- Pods have dynamic IPs that change on restart — Service gives a **stable internal DNS name**

---

```yaml
spec:
  selector:
    app: wisecow
```
- Selects pods with label `app: wisecow`
- **This is how the Service knows which pods to send traffic to** — by matching labels
- When pods are added/removed, Service automatically updates its endpoint list

---

```yaml
  ports:
    - protocol: TCP
      port: 80
      targetPort: 4499
```
- `port: 80` — the port **the Service listens on** (what you call from inside the cluster)
- `targetPort: 4499` — the port **on the pod** to forward to (where the app actually listens)
- So: `Service:80 → Pod:4499`
- Inside the cluster: `curl http://wisecow-service.wisecow.svc.cluster.local:80`

---

```yaml
  type: ClusterIP
```
- `ClusterIP` — **internal only**, not accessible from outside the cluster
- Gets a stable internal IP address like `10.96.x.x`
- Only reachable from inside the cluster (other pods, ingress controller)
- **Why not LoadBalancer?** NGINX Ingress handles external traffic — you don't expose every service directly

---

## 📄 3. `ingress.yaml` — External Traffic + TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wisecow-ingress
  namespace: wisecow
```
- `Ingress` — a K8s resource that defines HTTP/HTTPS routing rules
- Works with an **Ingress Controller** (NGINX in your case) which is the actual reverse proxy

---

```yaml
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
```
- `ingress.class: nginx` — tells which Ingress Controller to handle this (you might have multiple)
- `cert-manager.io/cluster-issuer: letsencrypt-prod` — triggers cert-manager to issue a TLS certificate using the `letsencrypt-prod` ClusterIssuer
- `ssl-redirect: true` — redirects HTTP → HTTPS
- `force-ssl-redirect: true` — forces HTTPS even if the request comes via HTTP internally

---

```yaml
spec:
  tls:
    - hosts:
        - www.checkmypro.online
      secretName: wisecow-tls
```
- `tls` — enables HTTPS for this Ingress
- `hosts` — which domain the certificate covers
- `secretName: wisecow-tls` — K8s secret where cert-manager **stores the TLS certificate and private key**. NGINX reads from this secret to terminate TLS.

---

```yaml
  rules:
    - host: www.checkmypro.online
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: wisecow-service
                port:
                  number: 80
```
- `host` — only requests to `www.checkmypro.online` match this rule
- `path: /` with `pathType: Prefix` — matches ALL paths starting with `/` (i.e., everything)
- `backend` — where to forward matched requests. Send to `wisecow-service` on port 80
- Full flow: `HTTPS request → NGINX → TLS terminated → forward to wisecow-service:80 → pod:4499`

---

## 📄 4. `cluster-issuer.yaml` — TLS Certificate Config

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
```
- `cert-manager.io/v1` — custom API added by cert-manager installation (a CRD — Custom Resource Definition)
- `ClusterIssuer` — cluster-wide certificate issuer (works across all namespaces, unlike `Issuer` which is namespace-scoped)

---

```yaml
metadata:
  name: letsencrypt-prod
```
- Named `letsencrypt-prod` — this name is referenced in `ingress.yaml` annotation: `cert-manager.io/cluster-issuer: letsencrypt-prod`

---

```yaml
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
```
- `acme` — Automated Certificate Management Environment protocol
- `server` — Let's Encrypt's **production** ACME server URL
- Use `https://acme-staging-v02.api.letsencrypt.org/directory` for testing (avoids rate limits)

---

```yaml
    email: anuragchauhan536@gmail.com
```
- Email for Let's Encrypt account — used for expiry notifications and account recovery

---

```yaml
    privateKeySecretRef:
      name: letsencrypt-prod
```
- cert-manager generates an **ACME account private key** and stores it in this K8s secret
- Used to authenticate with Let's Encrypt for future renewals

---

```yaml
    solvers:
      - http01:
          ingress:
            class: nginx
```
- `http01` — the ACME **challenge type** used to prove domain ownership
- How it works:
  1. Let's Encrypt gives cert-manager a **challenge token**
  2. cert-manager creates a temporary pod that serves the token at: `http://www.checkmypro.online/.well-known/acme-challenge/<token>`
  3. Let's Encrypt hits that URL and verifies it
  4. Domain ownership confirmed → TLS certificate issued
- `class: nginx` — use the NGINX Ingress to serve the challenge

---

## 📄 5. `configmap.yaml` — Empty Placeholder

```yaml
(empty file)
```
- A ConfigMap stores **non-sensitive configuration** as K8s objects (env vars, config files)
- This file is empty — currently the app only needs `PORT=4499` which is set directly in `deployment.yaml`'s `env` section
- **When would you use it?** If app needs config files mounted into pods, or many environment variables that change between environments (dev/staging/prod) without rebuilding the Docker image

---

## 🧠 Key Interview Q&A — All K8s Files

**Q: What is a namespace?**
> "A way to logically partition a K8s cluster. Resources in `wisecow` namespace are isolated from resources in `cert-manager` or `ingress-nginx`. Like folders in a filesystem."

**Q: How does the Service find the right pods?**
> "Label selectors — Service has `selector: app: wisecow`, and pods have `labels: app: wisecow`. K8s matches these and builds an `Endpoints` object listing the pod IPs."

**Q: What is the difference between Service and Ingress?**
| Service | Ingress |
|---|---|
| Internal load balancer between pods | External HTTP/HTTPS router |
| Layer 4 (TCP/UDP) | Layer 7 (HTTP, host/path routing) |
| ClusterIP = internal only | Routes public traffic to Services |
| No TLS termination | TLS termination here |

**Q: What is a CRD (Custom Resource Definition)?**
> "A way to extend K8s with custom resource types. `ClusterIssuer` and `Certificate` are not built-in K8s resources — cert-manager installs CRDs that add these new kinds. Same for Prometheus `ServiceMonitor`."

**Q: What happens when you `kubectl apply -f ingress.yaml`?**
> "K8s API server stores the object. NGINX Ingress Controller watches for Ingress objects and reconfigures its routing rules. cert-manager sees the `cluster-issuer` annotation and triggers ACME challenge → issues certificate → stores in the `wisecow-tls` secret."

**Q: What is `pathType: Prefix`?**
> "Matches any path that starts with `/`. So `/`, `/health`, `/about` all match. The alternative is `Exact` (only matches `/` exactly) or `ImplementationSpecific`."

**Q: Why does the service use port 80 but the app uses 4499?**
> "Service abstracts the port. Inside the cluster everything talks to `wisecow-service:80`. The Service translates port 80 → 4499 on the pod. This way if the app port changes, only the Service needs updating, not every caller."

**Q: What is an Endpoints object?**
> "Automatically created by K8s when a Service is created. It lists all pod IPs that match the Service's selector. `kubectl get endpoints -n wisecow` shows it. When pods restart and get new IPs, Endpoints updates automatically."

---

## 🔄 Complete Traffic Flow (All K8s Files Together)

```
User's Browser
      ↓ HTTPS request to www.checkmypro.online
AWS LoadBalancer (created by NGINX Ingress Controller)
      ↓ port 443
NGINX Ingress Controller Pod
      ↓ reads ingress.yaml rules
      ↓ terminates TLS using wisecow-tls secret (cert from Let's Encrypt)
      ↓ matches host: www.checkmypro.online, path: /
wisecow-service (ClusterIP, port 80)   ← service.yaml
      ↓ load balances across 3 pods
      ↓ translates port 80 → 4499
wisecow Pod (one of 3)                 ← deployment.yaml
      ↓ wisecow.sh: fortune + cowsay → HTML response
      ↑ HTTP 200 response
Back through the same chain to browser
```

---

## 🏗️ Terraform Files — Complete Line-by-Line Explanation (`terraform/` folder)

There are **4 active files** in `terraform/`:
1. `main.tf` — core infrastructure (VPC, EKS, networking)
2. `iam.tf` — IAM roles and permissions
3. `variable.tf` — input variables
4. `output.tf` — output values after apply

---

## 📄 1. `variable.tf` — Input Variables (Start Here)

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
```
- `variable` block — declares an **input parameter** for the Terraform configuration
- `description` — human-readable explanation (shown in `terraform plan` output)
- `type = string` — must be a string value
- `default = "us-east-1"` — used if no value is passed. Can be overridden with: `terraform apply -var="aws_region=ap-south-1"`

```hcl
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "wisecow-cluster"
}

variable "node_group_name" {
  description = "Name of the EKS node group"
  type        = string
  default     = "wisecow-nodes"
}
```
- 3 variables total: `aws_region`, `cluster_name`, `node_group_name`
- Referenced in `main.tf` as `var.aws_region`, `var.cluster_name`, `var.node_group_name`

**Q: How do you override a variable?**
> "Three ways: CLI flag `terraform apply -var="aws_region=eu-west-1"`, `.tfvars` file `aws_region = "eu-west-1"`, or environment variable `TF_VAR_aws_region=eu-west-1`"

---

## 📄 2. `main.tf` — Core Infrastructure

### Terraform Block

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```
- `terraform {}` block — global Terraform settings
- `required_providers` — declares which provider plugins are needed
- `source = "hashicorp/aws"` — downloads from the official HashiCorp registry
- `version = "~> 5.0"` — allow any `5.x` version but NOT `6.0`. The `~>` is called a **pessimistic constraint operator**

---

### Provider Block

```hcl
provider "aws" {
  region = var.aws_region
}
```
- `provider "aws"` — configures the AWS provider (how to connect to AWS)
- `region = var.aws_region` — reads from the variable (defaults to `us-east-1`)
- Terraform uses your local AWS credentials (`~/.aws/credentials` or environment variables)

---

### VPC

```hcl
resource "aws_vpc" "wisecow_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wisecow-vpc"
  }
}
```
- `resource "aws_vpc" "wisecow_vpc"` — creates an AWS VPC. First string = resource type, second = local name used to reference it
- `cidr_block = "10.0.0.0/16"` — IP address range. `/16` = 65,536 IP addresses (`10.0.0.0` to `10.0.255.255`)
- `enable_dns_hostnames = true` — EC2 instances get DNS hostnames like `ip-10-0-1-5.ec2.internal`
- `enable_dns_support = true` — enables AWS DNS resolver inside the VPC
- `tags` — metadata labels on AWS resources for identification and billing

**Q: What is a CIDR block?**
> "Classless Inter-Domain Routing — defines an IP address range. `10.0.0.0/16` means the first 16 bits are fixed (`10.0`), leaving 16 bits for host addresses = 65,536 IPs."

---

### Internet Gateway

```hcl
resource "aws_internet_gateway" "wisecow_igw" {
  vpc_id = aws_vpc.wisecow_vpc.id

  tags = {
    Name = "wisecow-igw"
  }
}
```
- **Internet Gateway (IGW)** — the door between your VPC and the public internet
- `vpc_id = aws_vpc.wisecow_vpc.id` — references the VPC created above. `.id` gets its AWS resource ID
- Without an IGW, nothing in the VPC can reach the internet

---

### Public Subnets

```hcl
resource "aws_subnet" "wisecow_public_subnet" {
  count             = 2
  vpc_id            = aws_vpc.wisecow_vpc.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "wisecow-public-subnet-${count.index + 1}"
  }
}
```
- `count = 2` — creates **2 subnets** using the same block (Terraform loop)
- `count.index` — 0 for first, 1 for second
- `cidr_block = "10.0.${count.index + 1}.0/24"`:
  - Subnet 1: `10.0.1.0/24` (256 IPs)
  - Subnet 2: `10.0.2.0/24` (256 IPs)
- `availability_zone` — places each subnet in a different AZ (`us-east-1a`, `us-east-1b`) for high availability
- `map_public_ip_on_launch = true` — EC2 instances launched here automatically get a public IP

**Q: Why 2 subnets in different AZs?**
> "EKS requires at least 2 subnets in different Availability Zones for high availability. If one AZ goes down, the other still has nodes running."

---

### Route Table

```hcl
resource "aws_route_table" "wisecow_public_rt" {
  vpc_id = aws_vpc.wisecow_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wisecow_igw.id
  }
}
```
- **Route Table** — tells traffic where to go based on destination IP
- `cidr_block = "0.0.0.0/0"` — catch-all rule: **all traffic** not matching other routes
- `gateway_id = aws_internet_gateway.wisecow_igw.id` — send that traffic to the Internet Gateway
- This makes the subnets **public** — traffic can reach the internet

```hcl
resource "aws_route_table_association" "wisecow_public_rta" {
  count          = 2
  subnet_id      = aws_subnet.wisecow_public_subnet[count.index].id
  route_table_id = aws_route_table.wisecow_public_rt.id
}
```
- **Associates** each subnet with the route table
- Without this, the route table exists but subnets don't use it

---

### Security Group

```hcl
resource "aws_security_group" "wisecow_eks_sg" {
  name        = "wisecow-eks-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.wisecow_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```
- **Security Group** = virtual firewall for AWS resources
- `ingress` — **inbound** rules: what traffic is allowed IN
  - Port 443 (HTTPS) allowed from anywhere (`0.0.0.0/0`)
- `egress` — **outbound** rules: what traffic is allowed OUT
  - `protocol = "-1"` = all protocols
  - `from_port = 0, to_port = 0` = all ports
  - All outbound traffic allowed (common default)

---

### EKS Cluster

```hcl
resource "aws_eks_cluster" "wisecow_cluster" {
  name     = "wisecow-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.wisecow_public_subnet[*].id
    security_group_ids = [aws_security_group.wisecow_eks_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
  ]
}
```
- `name = "wisecow-cluster"` — the EKS cluster name — used in `aws eks update-kubeconfig --name wisecow-cluster`
- `role_arn` — the IAM role the EKS **control plane** uses (from `iam.tf`)
- `vpc_config.subnet_ids = [*].id` — `[*]` = **splat expression** — gets IDs of ALL subnets created with `count`
- `depends_on` — tells Terraform to create the IAM policy attachments BEFORE the EKS cluster (explicit dependency ordering)

**Q: What is `depends_on`?**
> "Terraform normally figures out dependencies automatically via references. But IAM policy attachments don't appear in the EKS cluster config (no direct reference), so we explicitly tell Terraform: create these first, then create the cluster."

---

### EKS Node Group

```hcl
resource "aws_eks_node_group" "wisecow_nodes" {
  cluster_name    = aws_eks_cluster.wisecow_cluster.name
  node_group_name = "wisecow-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.wisecow_public_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  instance_types = ["t3.small"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]
}
```
- **Node Group** — the EC2 worker nodes where pods run
- `cluster_name` — links this node group to the EKS cluster
- `node_role_arn` — IAM role for worker nodes (from `iam.tf`)
- `scaling_config` — Auto Scaling Group settings:
  - `desired_size = 2` — start with 2 nodes
  - `max_size = 4` — can scale up to 4
  - `min_size = 1` — never go below 1
- `instance_types = ["t3.small"]` — EC2 instance type for worker nodes (2 vCPUs, 2GB RAM)

**Q: Why `t3.small`?**
> "It's cost-effective for a demo project — 2 vCPUs and 2GB RAM is enough for 3 small pods. In production you'd use `t3.medium` or larger depending on workload."

---

### Data Source

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}
```
- `data` block — reads **existing AWS information** (doesn't create anything)
- Fetches the list of available AZs in `us-east-1` at runtime (`us-east-1a`, `us-east-1b`, `us-east-1c`)
- Referenced by subnets: `data.aws_availability_zones.available.names[count.index]`

**Q: What is the difference between `resource` and `data` in Terraform?**
> "`resource` creates/manages infrastructure. `data` only reads information from AWS — it's read-only. Here I use `data` to get the list of AZs so I don't hardcode them."

---

## 📄 3. `iam.tf` — IAM Roles & Permissions

### EKS Cluster Role (Control Plane)

```hcl
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}
```
- Creates an IAM Role named `eks-cluster-role`
- `assume_role_policy` — the **trust policy**: WHO can assume this role
- `sts:AssumeRole` — the action that allows assuming the role
- `Principal.Service = "eks.amazonaws.com"` — **only the EKS service** can assume this role (not humans, not EC2)
- `jsonencode({})` — Terraform's built-in function to convert HCL object to JSON string (required by AWS API)

```hcl
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}
```
- `aws_iam_role_policy_attachment` — attaches an **AWS managed policy** to the role
- `AmazonEKSClusterPolicy` — allows EKS control plane to manage cluster resources (nodes, networking)
- `AmazonEKSServicePolicy` — allows EKS to create and manage AWS resources on your behalf

---

### EKS Node Role (Worker Nodes)

```hcl
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}
```
- `Principal.Service = "ec2.amazonaws.com"` — only EC2 instances (worker nodes) can assume this role
- Separate from cluster role — **principle of least privilege**: each component only gets permissions it needs

```hcl
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}
```
- `AmazonEKSWorkerNodePolicy` — allows EC2 nodes to **connect to and register with the EKS cluster**

```hcl
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}
```
- `AmazonEKS_CNI_Policy` — allows the **AWS VPC CNI plugin** to assign private IPs from the VPC to pods. Without this, pods can't get IP addresses.

```hcl
resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}
```
- `AmazonEC2ContainerRegistryReadOnly` — allows nodes to **pull Docker images** from ECR (Amazon's container registry). Needed for pulling base images.

**The 2 IAM Roles Summary:**
| Role | Trusted By | Policies | Purpose |
|---|---|---|---|
| `eks-cluster-role` | `eks.amazonaws.com` | EKSClusterPolicy + EKSServicePolicy | EKS control plane to manage AWS |
| `eks-node-role` | `ec2.amazonaws.com` | WorkerNode + CNI + ContainerRegistry | Worker nodes to join cluster + pull images |

---

## 📄 4. `output.tf` — Terraform Outputs

```hcl
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.wisecow_cluster.endpoint
}
```
- Outputs the EKS API server URL after `terraform apply`
- Example: `https://ABCD1234.gr7.us-east-1.eks.amazonaws.com`
- Used by `kubectl` to connect to the cluster

```hcl
output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = aws_eks_cluster.wisecow_cluster.vpc_config[0].cluster_security_group_id
}
```
- Outputs the security group ID auto-created by EKS for the control plane
- `vpc_config[0]` — gets the first (only) VPC config block

```hcl
output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = aws_eks_cluster.wisecow_cluster.name
}
```
- Outputs `wisecow-cluster` — used in: `aws eks update-kubeconfig --name <cluster_name>`

```hcl
output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.wisecow_cluster.certificate_authority[0].data
}
```
- The **CA certificate** — base64 encoded TLS certificate that `kubectl` uses to verify the EKS API server is legitimate
- Goes into `~/.kube/config` automatically via `aws eks update-kubeconfig`

**Q: Why do we need outputs?**
> "To expose values from created resources after `terraform apply`. Other tools, scripts, or team members can use `terraform output cluster_name` to get values without reading the state file directly."

---

## 🧠 Key Interview Q&A — All Terraform Files

**Q: What is `terraform init`?**
> "Downloads the required provider plugins (AWS provider in this case) and sets up the working directory. Must run before `plan` or `apply`."

**Q: What is `terraform plan`?**
> "Shows exactly what Terraform WILL create, modify, or destroy — without making any changes. A safe dry run. Shows green `+` for create, yellow `~` for modify, red `-` for destroy."

**Q: What is `terraform apply`?**
> "Actually executes the plan and creates/updates/destroys AWS resources. Uses `-auto-approve` in the Makefile to skip the interactive confirmation."

**Q: What is `terraform state`?**
> "A JSON file (`terraform.tfstate`) that maps your config to real AWS resources. Terraform compares desired state (code) vs current state (tfstate) to decide what to change."

**Q: What is the problem with local state?**
> "If two team members run `terraform apply` simultaneously, they both read/write the same state file and corrupt it. Fix: store state in **S3 with DynamoDB locking**."

**Q: What is `~>` in version constraints?**
> "Pessimistic constraint operator. `~> 5.0` allows `5.0`, `5.1`, `5.9` but NOT `6.0`. Protects against breaking changes in major versions."

**Q: What is the `[*]` splat expression?**
> "Gets the attribute from ALL items in a list. `aws_subnet.wisecow_public_subnet[*].id` returns the IDs of both subnets created with `count = 2`."

**Q: What is `jsonencode()`?**
> "A Terraform built-in function that converts an HCL object into a JSON string. IAM policies must be JSON strings, so we write them as HCL objects and convert."

**Q: What is `data` vs `resource`?**
> "`resource` creates and manages infrastructure. `data` is read-only — it fetches existing AWS information. I use `data.aws_availability_zones` to dynamically get AZ names instead of hardcoding them."

---

## 🔄 Terraform Infrastructure — What Gets Created

```
terraform apply creates:

VPC: 10.0.0.0/16
  ├── Subnet 1: 10.0.1.0/24 (us-east-1a) ← public
  ├── Subnet 2: 10.0.2.0/24 (us-east-1b) ← public
  ├── Internet Gateway (wisecow-igw)
  ├── Route Table → IGW (all traffic 0.0.0.0/0)
  ├── Route Table Associations (both subnets)
  └── Security Group (port 443 inbound, all outbound)

IAM:
  ├── eks-cluster-role (trusted by eks.amazonaws.com)
  │   ├── AmazonEKSClusterPolicy
  │   └── AmazonEKSServicePolicy
  └── eks-node-role (trusted by ec2.amazonaws.com)
      ├── AmazonEKSWorkerNodePolicy
      ├── AmazonEKS_CNI_Policy
      └── AmazonEC2ContainerRegistryReadOnly

EKS:
  ├── wisecow-cluster (control plane — AWS managed)
  └── wisecow-nodes (node group: 2 t3.small EC2 instances)
      └── Auto Scaling Group (min=1, desired=2, max=4)

Outputs:
  ├── cluster_endpoint
  ├── cluster_name
  ├── cluster_security_group_id
  └── cluster_certificate_authority_data
```

---

## 🤖 Ansible File — Complete Line-by-Line Explanation (`ansible/setup-cluster.yaml`)

There is **1 file** in `ansible/`:
- `setup-cluster.yaml` — installs and configures everything inside the EKS cluster after Terraform creates it

---

### What is Ansible?

- **Ansible** is an open-source **configuration management and automation tool**
- Uses **YAML playbooks** to define tasks to be executed on remote or local machines
- **Agentless** — no software needed on target machines, uses SSH (or `local` connection here)
- **Idempotent** — running the same playbook multiple times gives the same result (won't break things if run twice)

---

### Full File Walkthrough

```yaml
---
- name: Setup Kubernetes Cluster Components
  hosts: localhost
  connection: local
  gather_facts: no
```
- `---` — YAML document start marker
- `name` — human-readable description shown during `ansible-playbook` run
- `hosts: localhost` — run these tasks ON the local machine (not a remote server)
- `connection: local` — use local connection instead of SSH (since we're operating on localhost)
- `gather_facts: no` — skip automatic system fact collection (OS, memory, CPU info). Speeds up playbook since we don't need that info here

**Q: Why `hosts: localhost`?**
> "Because we're running Ansible on the same machine that has `kubectl`, `helm`, and AWS CLI installed. Ansible is just orchestrating local commands — not SSH'ing into a remote server."

---

```yaml
  vars:
    cluster_name: "wisecow-cluster"
    aws_region: "us-east-1"
```
- `vars` — defines reusable variables for this playbook
- Referenced later as `{{ cluster_name }}` and `{{ aws_region }}`
- Using variables instead of hardcoding makes the playbook reusable for different clusters/regions

---

### Task 1: Install kubectl

```yaml
    - name: Install kubectl
      become: yes
      shell: |
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        mv kubectl /usr/local/bin/kubectl
      args:
        executable: /bin/bash
```
- `name` — task description (shown in output)
- `become: yes` — **escalate to sudo/root** (needed to write to `/usr/local/bin/`)
- `shell: |` — runs a multi-line shell command. `|` = literal block scalar (preserves newlines)
- What the command does:
  1. `curl -LO` — downloads the latest stable `kubectl` binary from kubernetes.io
  2. `$(curl ... stable.txt)` — dynamically fetches the latest version number
  3. `chmod +x` — makes binary executable
  4. `mv kubectl /usr/local/bin/` — installs it system-wide
- `args.executable: /bin/bash` — use bash shell (not default `/bin/sh`)

**Q: Why download kubectl in Ansible instead of using the Makefile's `install-tools` target?**
> "This ensures kubectl is installed in the same automated pipeline as the cluster setup, without requiring a separate manual step."

---

### Task 2: Install Helm

```yaml
    - name: Install helm
      become: yes
      shell: |
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      args:
        executable: /bin/bash
```
- Downloads and runs the official Helm installation script
- `| bash` — pipes the script directly to bash for execution
- **Helm** = the **package manager for Kubernetes** — like `apt` for Ubuntu but for K8s apps
- Used to install NGINX Ingress, cert-manager, and Prometheus in later tasks

**Q: What is Helm?**
> "Helm is Kubernetes package manager. It packages K8s resources (deployments, services, configmaps) into reusable 'charts'. Instead of applying 20+ YAML files manually, you run one `helm install` command."

---

### Task 3: Update kubeconfig

```yaml
    - name: Update kubeconfig
      shell: |
        aws eks update-kubeconfig --region {{ aws_region }} --name {{ cluster_name }}
      environment:
        AWS_DEFAULT_REGION: "{{ aws_region }}"
```
- Runs `aws eks update-kubeconfig` to configure `kubectl` to talk to the EKS cluster
- `{{ aws_region }}` and `{{ cluster_name }}` — Ansible variable substitution (Jinja2 templating)
- `environment` — sets environment variables specifically for this task
- `AWS_DEFAULT_REGION` — tells AWS CLI which region to use without needing `-region` flag repeatedly

**Q: What does `aws eks update-kubeconfig` do?**
> "Updates `~/.kube/config` with the EKS cluster endpoint, CA certificate, and auth token. After this, `kubectl` can communicate with the EKS cluster."

---

### Task 4: Add NGINX Ingress Helm Repo

```yaml
    - name: Add NGINX Ingress Controller Helm repo
      kubernetes.core.helm_repository:
        name: ingress-nginx
        repo_url: https://kubernetes.github.io/ingress-nginx
```
- `kubernetes.core.helm_repository` — Ansible module (from `kubernetes.core` collection) to manage Helm repos
- Equivalent to: `helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx`
- Adds the repo so Helm knows where to download the NGINX ingress chart from

---

### Task 5: Install NGINX Ingress Controller

```yaml
    - name: Install NGINX Ingress Controller
      kubernetes.core.helm:
        name: ingress-nginx
        chart_ref: ingress-nginx/ingress-nginx
        release_namespace: ingress-nginx
        create_namespace: true
        values:
          controller:
            service:
              type: LoadBalancer
            admissionWebhooks:
              enabled: false
```
- `kubernetes.core.helm` — Ansible module to install/manage Helm releases
- `name: ingress-nginx` — the Helm **release name**
- `chart_ref: ingress-nginx/ingress-nginx` — repo/chart format. Installs the `ingress-nginx` chart from the `ingress-nginx` repo
- `release_namespace: ingress-nginx` — installs into the `ingress-nginx` namespace
- `create_namespace: true` — creates the namespace if it doesn't exist
- `values:` — overrides default chart values (like `helm install --set key=value`):
  - `controller.service.type: LoadBalancer` — creates an **AWS Load Balancer** for external traffic
  - `admissionWebhooks.enabled: false` — disables webhook validation (avoids permission issues in some setups)

**Q: What is NGINX Ingress Controller?**
> "A pod running NGINX inside the cluster that watches Kubernetes Ingress objects and configures NGINX routing rules. It also creates an AWS LoadBalancer so external traffic can reach it."

---

### Task 6: Add cert-manager Helm Repo

```yaml
    - name: Add cert-manager Helm repo
      kubernetes.core.helm_repository:
        name: jetstack
        repo_url: https://charts.jetstack.io
```
- Adds the Jetstack Helm repo (cert-manager's official publisher)
- Equivalent to: `helm repo add jetstack https://charts.jetstack.io`

---

### Task 7: Install cert-manager

```yaml
    - name: Install cert-manager
      kubernetes.core.helm:
        name: cert-manager
        chart_ref: jetstack/cert-manager
        release_namespace: cert-manager
        create_namespace: true
        values:
          installCRDs: true
```
- Installs cert-manager into the `cert-manager` namespace
- `installCRDs: true` — **critical setting**: installs Custom Resource Definitions (CRDs) like `Certificate`, `ClusterIssuer`, `CertificateRequest`
- Without CRDs, `kubectl apply -f cluster-issuer.yaml` would fail because K8s doesn't know what a `ClusterIssuer` is

**Q: What is a CRD and why does cert-manager need to install them?**
> "CRDs extend the Kubernetes API with new resource types. `ClusterIssuer`, `Certificate`, `CertificateRequest` are not built into Kubernetes — cert-manager adds them. `installCRDs: true` tells Helm to install these definitions first before deploying cert-manager itself."

---

### Task 8: Wait for cert-manager to be Ready

```yaml
    - name: Wait for cert-manager to be ready
      kubernetes.core.k8s_info:
        api_version: apps/v1
        kind: Deployment
        name: cert-manager
        namespace: cert-manager
        wait: true
        wait_condition:
          type: Available
          status: "True"
        wait_timeout: 600
```
- `kubernetes.core.k8s_info` — queries K8s for resource status
- `wait: true` — **blocks playbook execution** until the condition is met
- `wait_condition.type: Available` — waits until the cert-manager Deployment is Available
- `wait_timeout: 600` — timeout after 600 seconds (10 minutes)

**Q: Why wait for cert-manager before the next task?**
> "The next task creates a `ClusterIssuer` which is a cert-manager CRD. If cert-manager isn't running yet, the API server won't recognize the `ClusterIssuer` kind and the task will fail."

---

### Task 9: Apply ClusterIssuer

```yaml
    - name: Apply cluster issuer
      kubernetes.core.k8s:
        definition:
          apiVersion: cert-manager.io/v1
          kind: ClusterIssuer
          metadata:
            name: letsencrypt-prod
          spec:
            acme:
              server: https://acme-v02.api.letsencrypt.org/directory
              email: anuragchauhan536@gmail.com
              privateKeySecretRef:
                name: letsencrypt-prod
              solvers:
                - http01:
                    ingress:
                      class: nginx
```
- `kubernetes.core.k8s` — applies a K8s manifest directly from Ansible (no YAML file needed)
- `definition:` — the full K8s resource definition inline (same as `cluster-issuer.yaml`)
- Creates the `ClusterIssuer` named `letsencrypt-prod` — this is referenced by `ingress.yaml`'s annotation
- This is the **same content** as `k8s/cluster-issuer.yaml` — just applied via Ansible instead of `kubectl`

**Q: Why apply ClusterIssuer via Ansible and also have `cluster-issuer.yaml`?**
> "Both do the same thing. The Ansible task handles it as part of the automated cluster setup flow. The YAML file exists for manual application or re-application if needed."

---

### Task 10: Create wisecow Namespace

```yaml
    - name: Create wisecow namespace
      kubernetes.core.k8s:
        name: wisecow
        api_version: v1
        kind: Namespace
        state: present
```
- Creates the `wisecow` namespace where the app will be deployed
- `state: present` — ensures it exists. If already exists, does nothing (idempotent)
- `state: absent` would delete it

---

### Task 11: Add Prometheus Helm Repo

```yaml
    - name: Add prometheus-community Helm repo
      kubernetes.core.helm_repository:
        name: prometheus-community
        repo_url: https://prometheus-community.github.io/helm-charts
```
- Adds the Prometheus Community Helm repo
- Equivalent to: `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`

---

### Task 12: Install kube-prometheus-stack

```yaml
    - name: Install kube-prometheus-stack
      kubernetes.core.helm:
        name: prometheus
        chart_ref: prometheus-community/kube-prometheus-stack
        release_namespace: monitoring
        create_namespace: true
```
- Installs the **kube-prometheus-stack** — a bundled Helm chart containing:
  - **Prometheus** — metrics collection
  - **Grafana** — metrics visualization dashboard
  - **AlertManager** — alerting rules
  - **kube-state-metrics** — K8s object metrics
  - **node-exporter** — host/node metrics
- `release_namespace: monitoring` — all monitoring components go in the `monitoring` namespace
- `create_namespace: true` — creates it if not present

---

## 🧠 Key Interview Q&A — Ansible

## 🔑 Key Tools Installed by Ansible — What They Are

---

### 🌐 What is NGINX Ingress Controller?

**NGINX** is a popular open-source web server and reverse proxy. The **NGINX Ingress Controller** is a special pod running inside Kubernetes that:

1. Watches Kubernetes `Ingress` objects for routing rules
2. Configures the NGINX reverse proxy to route traffic accordingly
3. Creates an **AWS Load Balancer** (via `type: LoadBalancer` service) that accepts external traffic

```
Internet → AWS Load Balancer → NGINX Ingress Controller Pod → Service → App Pods
```

**Without it:** You'd need a separate LoadBalancer for every service = expensive and hard to manage.  
**With it:** ONE load balancer handles ALL traffic, routes by host/path rules to different services.

**Q: What is a reverse proxy?**
> "A server that sits in front of other servers and forwards client requests to them. Clients talk to NGINX, NGINX talks to the backend. Benefits: load balancing, SSL termination, routing, rate limiting."

**Q: What is TLS termination?**
> "Decrypting HTTPS traffic at the ingress point and forwarding as plain HTTP internally. The app doesn't need to handle TLS — NGINX does it. This is what `ssl-redirect: true` does in `ingress.yaml`."

**Q: Why `admissionWebhooks: enabled: false`?**
> "Admission webhooks validate Kubernetes objects before they're created. The NGINX webhook validates Ingress objects. Disabling it avoids permission issues in some cluster setups during initial install."

---

### 🔒 What is cert-manager?

**cert-manager** is a Kubernetes add-on that **automatically provisions, manages, and renews TLS certificates**. It eliminates the need to manually obtain and rotate SSL certificates.

**How it works:**

```
1. You create a ClusterIssuer (tells cert-manager: use Let's Encrypt)
2. You add annotation to Ingress: cert-manager.io/cluster-issuer: letsencrypt-prod
3. cert-manager sees the Ingress → starts ACME HTTP-01 challenge
4. Creates a temporary pod to serve the challenge token at:
   http://www.checkmypro.online/.well-known/acme-challenge/<token>
5. Let's Encrypt verifies the token → confirms domain ownership
6. Let's Encrypt issues a 90-day TLS certificate
7. cert-manager stores it in K8s Secret (wisecow-tls)
8. NGINX reads the secret → serves HTTPS
9. cert-manager auto-renews at 60 days
```

**Key cert-manager resources:**

| Resource | What It Is |
|---|---|
| `ClusterIssuer` | Configuration: which CA to use (Let's Encrypt), what email, which challenge solver |
| `Certificate` | Represents a TLS certificate (auto-created by cert-manager from Ingress annotation) |
| `CertificateRequest` | Intermediate object: the actual request sent to Let's Encrypt |
| `Order` | The ACME order placed with Let's Encrypt |
| `Challenge` | The HTTP-01 challenge object (temporary, deleted after verification) |

**Q: What is ACME?**
> "Automated Certificate Management Environment — a protocol for automatically proving domain ownership and getting TLS certificates. Let's Encrypt uses ACME. cert-manager implements the ACME client."

**Q: What is HTTP-01 challenge?**
> "Let's Encrypt gives cert-manager a token. cert-manager serves it at `http://<domain>/.well-known/acme-challenge/<token>`. Let's Encrypt fetches that URL — if it gets the token back, it proves you control the domain → issues certificate."

**Q: What are CRDs that cert-manager installs?**
> "Custom Resource Definitions — they extend Kubernetes with new resource types. `ClusterIssuer`, `Certificate`, `CertificateRequest` don't exist in standard K8s. cert-manager adds them via `installCRDs: true` in Helm."

**Q: What happens when cert-manager renews a certificate?**
> "cert-manager watches the certificate's expiry. At 60 days remaining (30 days before Let's Encrypt's 90-day expiry), it automatically starts a new ACME challenge, gets a fresh certificate, and updates the `wisecow-tls` secret. NGINX picks up the new cert automatically. Zero manual work."

---

### ⚓ What is Helm?

**Helm** is the **package manager for Kubernetes** — like `apt` for Ubuntu or `npm` for Node.js, but for K8s apps.

**The problem Helm solves:**
> Deploying NGINX Ingress Controller requires ~15 YAML files (Deployment, Service, ServiceAccount, ClusterRole, ClusterRoleBinding, ConfigMap, etc.). Managing and updating these manually is painful.

**Helm solves this with:**

| Concept | What It Is |
|---|---|
| **Chart** | A package of K8s YAML templates (like an `.deb` or `.npm` package) |
| **Release** | An installed instance of a chart in a cluster |
| **Repository** | A collection of charts (like npm registry or apt repo) |
| **Values** | Configuration overrides for a chart's defaults |

**Helm workflow in your project:**

```bash
# 1. Add repo (where to find charts)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# 2. Install chart (creates a "release")
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

# 3. Update/upgrade
helm upgrade ingress-nginx ingress-nginx/ingress-nginx

# 4. Remove
helm uninstall ingress-nginx -n ingress-nginx
```

**Q: What is a Helm chart?**
> "A collection of YAML template files packaged together. Templates have placeholders like `{{ .Values.service.type }}` that get replaced with your custom values at install time."

**Q: What is `values:` in Ansible helm module?**
> "It's equivalent to `helm install --set key=value`. You're overriding chart defaults. `controller.service.type: LoadBalancer` overrides the default `ClusterIP` to create an AWS LoadBalancer."

**Q: What is `installCRDs: true` in cert-manager?**
> "A chart value that tells Helm to also install the Custom Resource Definitions before deploying cert-manager. Without CRDs, the cert-manager pods can't create `Certificate` or `ClusterIssuer` objects."

**Q: What is a Helm release?**
> "A deployed instance of a chart. `helm install ingress-nginx ...` creates a release named `ingress-nginx`. You can have multiple releases of the same chart (e.g., one for staging, one for prod)."

**Q: How is Helm different from `kubectl apply`?**
> "`kubectl apply` applies static YAML. Helm is templated — the same chart can create different resources based on values. Helm also tracks what it deployed (in a secret), so `helm upgrade` knows what to change and `helm uninstall` knows what to delete."

---

**Q: What is Ansible vs Terraform?**
| | Ansible | Terraform |
|---|---|---|
| **Purpose** | Configuration management, app deployment | Infrastructure provisioning |
| **What it manages** | Software, configs, K8s objects | AWS VPCs, EKS, EC2, IAM |
| **Language** | YAML playbooks | HCL (HashiCorp Config Language) |
| **State** | Stateless (re-runs tasks every time) | Stateful (tracks what exists in `.tfstate`) |
| **Idempotent** | Yes (modules check before acting) | Yes (compares desired vs current state) |

**Q: What is idempotency?**
> "Running the same operation multiple times produces the same result. If cert-manager is already installed, `helm install` via Ansible won't install it twice — it checks first. `state: present` on a namespace that already exists = no action."

**Q: What is the `kubernetes.core` collection?**
> "An Ansible collection (plugin package) that provides modules for interacting with Kubernetes. Modules like `kubernetes.core.helm`, `kubernetes.core.k8s`, `kubernetes.core.k8s_info` are more native and reliable than running `kubectl` via the `shell` module."

**Q: What is Jinja2 templating in Ansible?**
> "`{{ variable_name }}` syntax — Ansible replaces this at runtime with the actual value. `{{ aws_region }}` becomes `us-east-1`. It's the same engine as used in Flask/Django templates."

**Q: What does `become: yes` do?**
> "Privilege escalation — runs the task as root/sudo. Required for installing binaries to system paths like `/usr/local/bin/`. Without it, the task would fail with permission denied."

**Q: What is `gather_facts: no`?**
> "By default Ansible collects system information (OS, RAM, CPU, network interfaces) at the start. We don't need that here, so we disable it to speed up the playbook."

**Q: Why use Ansible for this instead of just shell scripts?**
> "Ansible provides: idempotency (checks before acting), better error handling with `failed_when`/`ignore_errors`, native K8s modules (`kubernetes.core`), readable YAML structure, and the ability to wait for conditions (`wait: true`). Shell scripts would be more fragile."

---

## 🔄 Ansible Execution Order

```
ansible-playbook ansible/setup-cluster.yaml

Task 1:  Install kubectl          → /usr/local/bin/kubectl ✅
Task 2:  Install Helm             → /usr/local/bin/helm ✅
Task 3:  Update kubeconfig        → ~/.kube/config updated ✅
Task 4:  Add ingress-nginx repo   → helm repo added ✅
Task 5:  Install NGINX Ingress    → ingress-nginx namespace, LoadBalancer created ✅
Task 6:  Add jetstack repo        → helm repo added ✅
Task 7:  Install cert-manager     → cert-manager namespace, CRDs installed ✅
Task 8:  Wait for cert-manager    → blocks until cert-manager pod is Ready ✅
Task 9:  Apply ClusterIssuer      → letsencrypt-prod ClusterIssuer created ✅
Task 10: Create wisecow namespace → wisecow namespace created ✅
Task 11: Add prometheus repo      → helm repo added ✅
Task 12: Install kube-prometheus  → monitoring namespace, Prometheus + Grafana ✅

Result: Cluster is fully configured and ready for app deployment
```

---

## 📁 Scripts — Complete Line-by-Line Explanation (`scripts/` folder)

4 utility scripts used by the Makefile and deployment pipeline:
1. `deploy.sh` — full deployment automation
2. `health-check.sh` — comprehensive health verification
3. `monitor.sh` — real-time status dashboard
4. `cleanup.sh` — resource teardown

---

## 📄 1. `scripts/deploy.sh` — Full Deployment Script

```bash
#!/bin/bash
set -e
```
- `#!/bin/bash` — shebang: use bash interpreter
- `set -e` — **exit immediately if any command fails**. If `terraform apply` errors, the script stops instantly instead of continuing and causing worse failures downstream

---

```bash
AWS_REGION="us-east-1"
CLUSTER_NAME="wisecow-cluster"
NAMESPACE="wisecow"
```
- Configuration variables at the top — easy to change in one place
- Referenced throughout the script as `$AWS_REGION`, `$CLUSTER_NAME`, `$NAMESPACE`

---

```bash
command_exists() {
    command -v "$1" >/dev/null 2>&1
}
```
- Defines a **reusable function** that checks if a command exists in PATH
- `command -v` — returns 0 if found, 1 if not
- `>/dev/null 2>&1` — silences both stdout and stderr
- `"$1"` — the first argument passed to the function (quoted to handle spaces)

---

```bash
required_tools=("aws" "kubectl" "helm" "terraform")
for tool in "${required_tools[@]}"; do
    if ! command_exists "$tool"; then
        echo -e "${RED}Error: $tool is not installed${NC}"
        exit 1
    fi
done
```
- `required_tools=(...)` — **bash array** of tool names
- `"${required_tools[@]}"` — expands entire array, each element quoted
- `for tool in ...` — loops over each tool
- `if ! command_exists "$tool"` — if tool NOT found → print red error + exit 1
- **Fails fast** — checks all prerequisites BEFORE starting, not halfway through

---

```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
cd ..
```
- `cd terraform` — change into terraform directory
- Three-phase Terraform flow: init → plan → apply
- `-auto-approve` — skips the interactive "yes" confirmation
- `cd ..` — return to project root

---

```bash
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
```
- Updates `~/.kube/config` so kubectl can connect to the EKS cluster

---

```bash
ansible-playbook ansible/setup-cluster.yaml
```
- Runs the Ansible playbook to configure the cluster

---

```bash
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s
```
- **Blocks script execution** until condition is met
- `--for=condition=ready` — waits for pod `Ready` condition = true
- `--selector=...component=controller` — targets the NGINX ingress controller pod specifically
- `--timeout=300s` — gives up after 5 minutes
- **Why wait?** If we `kubectl apply ingress.yaml` before NGINX controller is ready, the Ingress object won't be processed

---

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/cluster-issuer.yaml
kubectl apply -f k8s/ingress.yaml
```
- Applies all K8s manifests in the correct order

---

```bash
kubectl wait --for=condition=available --timeout=300s deployment/wisecow-deployment -n "$NAMESPACE"
```
- Waits until the deployment's `Available` condition is true (all replicas ready)
- Script only continues (and prints success) after deployment is confirmed healthy

---

```bash
LB_URL=$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo -e "${GREEN}LoadBalancer URL: http://$LB_URL${NC}"
```
- `$(...)` — command substitution: captures output
- `-o jsonpath='{...}'` — extracts only the hostname field from the service JSON
- Prints the LoadBalancer URL for DNS configuration

---

## 📄 2. `scripts/health-check.sh` — Health Check Script

```bash
set -e
NAMESPACE="wisecow"
DEPLOYMENT="wisecow-deployment"
SERVICE="wisecow-service"
```
- Variables for the resources being checked

---

```bash
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
        return 0
    else
        echo -e "${RED}✗ $1${NC}"
        return 1
    fi
}
```
- `$?` — **exit code of the last command** (0 = success, non-zero = failure)
- Re-usable function: called after every check to print ✓ or ✗ with color
- `$1` — the check name passed as argument (e.g., "Cluster connectivity")

---

**The 10 health checks in order:**

```bash
# Check 1: Cluster connectivity
kubectl cluster-info &>/dev/null
check_status "Cluster connectivity"
```
- `&>/dev/null` — redirect both stdout AND stderr to /dev/null (silence everything)

```bash
# Check 2: Namespace
kubectl get namespace "$NAMESPACE" &>/dev/null
check_status "Namespace $NAMESPACE exists"
```

```bash
# Check 3 & 4: Deployment + replica count
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" &>/dev/null
READY_REPLICAS=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.status.readyReplicas}')
DESIRED_REPLICAS=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.replicas}')

if [ "$READY_REPLICAS" = "$DESIRED_REPLICAS" ]; then
    echo -e "${GREEN}✓ Deployment is ready ($READY_REPLICAS/$DESIRED_REPLICAS replicas)${NC}"
```
- `jsonpath='{.status.readyReplicas}'` — extracts only the ready replica count
- Compares ready vs desired — must be equal for health

```bash
# Check 5: Pods running
RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=wisecow \
  --field-selector=status.phase=Running -o name | wc -l)
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=wisecow -o name | wc -l)
```
- `-l app=wisecow` — label selector filter
- `--field-selector=status.phase=Running` — only Running pods
- `| wc -l` — counts lines = number of pods

```bash
# Check 8: TLS Certificate
CERT_READY=$(kubectl get certificates -n "$NAMESPACE" \
  -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
if [ "$CERT_READY" = "True" ]; then
```
- Complex jsonpath: `[?(@.type=="Ready")]` — filter condition: find the condition where type equals "Ready"
- Checks if TLS certificate issued by cert-manager is ready

```bash
# Check 9: Hit LoadBalancer URL
LB_URL=$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if curl -s -o /dev/null -w "%{http_code}" "http://$LB_URL" | grep -q "200\|302\|301"; then
```
- `curl -s` — silent mode
- `-o /dev/null` — discard response body
- `-w "%{http_code}"` — print only the HTTP status code
- `grep -q "200\|302\|301"` — checks for success or redirect codes

```bash
# Check 10: Resource usage
kubectl top pods -n "$NAMESPACE"
```
- Shows CPU and memory per pod (requires metrics-server)

```bash
# Final exit code
if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo -e "${GREEN}Overall Status: HEALTHY${NC}"
    exit 0
else
    echo -e "${RED}Overall Status: UNHEALTHY${NC}"
    exit 1
fi
```
- `exit 0` = healthy (success) — used by CI/CD pipelines to know deployment succeeded
- `exit 1` = unhealthy (failure) — CI/CD can act on this (alert, rollback)

---

## 📄 3. `scripts/monitor.sh` — Monitoring Dashboard

```bash
NAMESPACE="wisecow"

# Check cluster connection first
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}Cannot connect to cluster. Please check your kubeconfig.${NC}"
    exit 1
fi
```
- **Fail early** — if can't connect to cluster, no point showing anything else

---

```bash
echo -e "${BLUE}Deployment Status:${NC}"
kubectl get deployment -n "$NAMESPACE"

echo -e "${BLUE}Pod Status:${NC}"
kubectl get pods -n "$NAMESPACE" -o wide
```
- `-o wide` — shows extra columns: node name, pod IP, nominated node

```bash
echo -e "${BLUE}Certificate Status:${NC}"
kubectl get certificates -n "$NAMESPACE" 2>/dev/null || echo "No certificates found"
```
- `2>/dev/null` — redirect stderr to /dev/null (no error if cert-manager not installed)
- `|| echo "No certificates found"` — fallback message if command fails

```bash
echo -e "${BLUE}Recent Events:${NC}"
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
```
- `--sort-by='.lastTimestamp'` — sorts events by time (most recent last)
- `tail -10` — show only last 10 events

```bash
echo -e "${BLUE}Resource Usage:${NC}"
kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "Metrics server not available"
```
- Shows live CPU/memory for each pod
- Falls back gracefully if metrics-server not installed

```bash
LB_URL=$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "$LB_URL" ]; then
    echo -e "${GREEN}LoadBalancer URL: http://$LB_URL${NC}"
else
    echo -e "${YELLOW}LoadBalancer URL not available yet${NC}"
fi
```
- `[ -n "$LB_URL" ]` — `-n` tests if string is NOT empty
- Shows URL if available, warning message if not

```bash
READY_PODS=$(kubectl get pods -n "$NAMESPACE" \
  -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | wc -w)
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" \
  -o jsonpath='{.items[*].metadata.name}' | wc -w)
```
- `[?(@.status.phase=="Running")]` — jsonpath filter for Running pods
- `| wc -w` — count words (each pod name = one word)

---

## 📄 4. `scripts/cleanup.sh` — Resource Teardown

```bash
set -e
```
- Stop immediately if anything fails during cleanup

---

```bash
kubectl delete -f k8s/ingress.yaml --ignore-not-found=true
kubectl delete -f k8s/service.yaml --ignore-not-found=true
kubectl delete -f k8s/deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/cluster-issuer.yaml --ignore-not-found=true
```
- `--ignore-not-found=true` — **idempotent**: won't error if resource already gone
- **Correct order**: ingress first (depends on service), then service, then deployment
- Why ingress first? Remove the front door before shutting down the rooms

```bash
helm uninstall cert-manager -n cert-manager --ignore-not-found
helm uninstall ingress-nginx -n ingress-nginx --ignore-not-found
```
- Uninstalls Helm releases (removes all resources created by those charts)
- Must be done BEFORE deleting namespaces

```bash
kubectl delete namespace wisecow --ignore-not-found=true
kubectl delete namespace cert-manager --ignore-not-found=true
kubectl delete namespace ingress-nginx --ignore-not-found=true
```
- Deletes namespaces — this also deletes ALL resources inside them
- Deleting a namespace is thorough but irreversible

```bash
cd terraform
terraform destroy -auto-approve
cd ..
```
- **Final step** — tears down AWS infrastructure
- Must be LAST — EKS must still exist while we're running kubectl commands above
- `-auto-approve` — no interactive confirmation

**Cleanup reverse order:**
```
K8s App → Helm Charts → Namespaces → AWS Infrastructure (Terraform)
```
This is the reverse of the deployment order — dependencies last.

---

## 🛠️ Makefile — Complete Line-by-Line Explanation

```makefile
# Variables
CLUSTER_NAME ?= wisecow-cluster
AWS_REGION   ?= us-east-1
NAMESPACE    ?= wisecow
IMAGE_TAG    ?= latest
REGISTRY     ?= ghcr.io/anuragstark/wisecow
```
- `?=` — **conditional assignment**: only set if the variable is NOT already defined in the environment
- Can override at runtime: `make build IMAGE_TAG=v2.0` → uses `v2.0` instead of `latest`
- `REGISTRY` — the full Docker image path without the tag

---

```makefile
YELLOW := \033[1;33m
GREEN  := \033[0;32m
RED    := \033[0;31m
NC     := \033[0m
```
- ANSI color codes for colored terminal output
- `\033[` — escape sequence start
- `NC` = "No Color" — resets color after a colored message
- Used as: `echo -e "$(YELLOW)Building...$(NC)"`

---

```makefile
.PHONY: help build deploy clean monitor health-check logs
```
- **`.PHONY`** — declares these as "phony" targets (not real files)
- Without this, if a file named `build` existed in the directory, Make would think the target is already up-to-date and skip it
- Always declare non-file targets as `.PHONY`

---

```makefile
help: ## Display this help message
	@echo "Wisecow Application Management"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / \
	  {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
```
- `@` before a command — suppresses printing the command itself (only shows output)
- `awk` — scans the Makefile for lines with `##` comments and formats them as a help table
- `$$1` = first field (target name), `$$2` = second field (description)
- `$(MAKEFILE_LIST)` — refers to the current Makefile
- **Self-documenting** — `make help` auto-generates usage from `##` comments

---

```makefile
build: ## Build Docker image
	@echo -e "$(YELLOW)Building Docker image...$(NC)"
	docker build -t $(REGISTRY):$(IMAGE_TAG) .
	@echo -e "$(GREEN)Image built successfully$(NC)"
```
- Builds Docker image and tags it as `ghcr.io/anuragstark/wisecow:latest`
- Color feedback: yellow during, green on success

---

```makefile
push: ## Push Docker image to registry
	docker push $(REGISTRY):$(IMAGE_TAG)
```
- Pushes the previously built image to GHCR

---

```makefile
terraform-init:   ## Initialize Terraform
	cd terraform && terraform init

terraform-plan:   ## Plan Terraform deployment
	cd terraform && terraform plan

terraform-apply:  ## Apply Terraform configuration
	cd terraform && terraform apply -auto-approve

terraform-destroy: ## Destroy Terraform infrastructure
	cd terraform && terraform destroy -auto-approve
```
- Each target runs a single Terraform command in the `terraform/` subdirectory
- `cd terraform && command` — change directory and run in one shell (Makefile doesn't persist `cd` between lines)

---

```makefile
kubeconfig: ## Update kubeconfig
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)
```

---

```makefile
setup-cluster: ## Setup cluster components with Ansible
	ansible-playbook ansible/setup-cluster.yaml --ask-become-pass
```
- `--ask-become-pass` — prompts for sudo password interactively (needed for `become: yes` tasks)

---

```makefile
deploy-app: ## Deploy application to Kubernetes
	kubectl apply -f k8s/deployment.yaml
	kubectl apply -f k8s/service.yaml
	kubectl apply -f k8s/cluster-issuer.yaml
	kubectl apply -f k8s/ingress.yaml
```
- Applies all K8s manifests in order

---

```makefile
deploy: terraform-apply kubeconfig setup-cluster deploy-app ## Full deployment
	@echo -e "$(GREEN)Full deployment completed$(NC)"
	@$(MAKE) health-check
```
- **Chained dependencies** — Makefile runs: `terraform-apply` → `kubeconfig` → `setup-cluster` → `deploy-app` in order before the recipe body runs
- `@$(MAKE) health-check` — calls another Make target recursively. `$(MAKE)` is used instead of `make` to ensure the correct Make version is used

---

```makefile
scale: ## Scale application (usage: make scale REPLICAS=5)
	kubectl scale deployment wisecow-deployment --replicas=$(REPLICAS) -n $(NAMESPACE)
```
- `$(REPLICAS)` — must be passed at runtime: `make scale REPLICAS=5`
- If not passed, `$(REPLICAS)` is empty → kubectl error

---

```makefile
restart: ## Restart application
	kubectl rollout restart deployment/wisecow-deployment -n $(NAMESPACE)
	kubectl rollout status deployment/wisecow-deployment -n $(NAMESPACE)
```
- `rollout restart` — triggers a new rollout without changing the image
- Useful to pick up ConfigMap changes or just to recycle pods
- `rollout status` — waits and shows progress of the restart

---

```makefile
get-url: ## Get application URL
	@LB_URL=$$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
	  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'); \
	if [ -n "$$LB_URL" ]; then \
	    echo -e "$(GREEN)Application URL: http://$$LB_URL$(NC)"; \
	else \
	    echo -e "$(RED)LoadBalancer URL not available$(NC)"; \
	fi
```
- `$$` in Makefile = literal `$` in shell (Makefile uses `$` for its own variables)
- `$$(...)` = shell command substitution `$(...)` inside Makefile
- `[ -n "$$LB_URL" ]` = if URL string is NOT empty

---

```makefile
debug: ## Debug application issues
	@echo "--- Pods ---"
	kubectl get pods -n $(NAMESPACE) -o wide
	@echo "--- Events ---"
	kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -10
	@echo "--- Pod Logs ---"
	kubectl logs -l app=wisecow -n $(NAMESPACE) --tail=50
```
- **One command, full context** — pods + events + logs in one shot
- Designed for quick debugging without typing 3 separate kubectl commands

---

```makefile
install-tools: ## Install required tools
	curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	chmod +x kubectl
	sudo mv kubectl /usr/local/bin/
	curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
	wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | \
	  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
	sudo apt update && sudo apt install terraform
```
- Installs kubectl, Helm, and Terraform on a fresh Ubuntu machine
- Terraform: adds HashiCorp's official APT repo + GPG key, then installs via `apt`

---

```makefile
all: deploy
```
- **Default target** — running plain `make` (no target specified) runs `deploy`
- `all` is a conventional default target name in Makefiles

---

## 🧠 Key Interview Q&A — Scripts & Makefile

**Q: What is `set -e` and why is it important?**
> "Exit on error — if any command in the script returns a non-zero exit code, the script immediately stops. Without it, a failed `terraform apply` would be silently ignored and the script would try to run `kubectl` on a cluster that wasn't created."

**Q: What is `$?` in bash?**
> "The exit code of the most recently executed command. `0` = success, anything else = failure. Used in `check_status()` to determine if the previous kubectl command succeeded."

**Q: What is `"${array[@]}"` in bash?**
> "Expands a bash array into separate quoted elements. `required_tools=('aws' 'kubectl')` then `'${required_tools[@]}'` gives `'aws'` `'kubectl'` as separate arguments to the for loop."

**Q: What is `-o jsonpath` in kubectl?**
> "Output format flag. `jsonpath` lets you extract specific fields from K8s JSON output using a path expression. `{.status.readyReplicas}` pulls only that field instead of the full YAML/JSON."

**Q: What is `wc -l` vs `wc -w`?**
> "`wc -l` counts lines. `wc -w` counts words (space-separated tokens). When kubectl returns pod names separated by spaces on one line, `wc -w` counts them correctly."

**Q: What does `?=` mean in Makefile?**
> "Conditional assignment — only sets the variable if it's not already defined. Allows overriding: `make build IMAGE_TAG=v2.0` sets `IMAGE_TAG` before Make reads the Makefile, so `?=` doesn't overwrite it."

**Q: Why `$$` in Makefile shell commands?**
> "Makefile uses `$` for its own variable substitution. To use a shell variable or command substitution (`$(cmd)`) inside a Makefile recipe, escape the `$` as `$$`. So `$$(curl ...)` becomes `$(curl ...)` in the actual shell command."

**Q: What is `$(MAKE)` vs `make` in Makefile?**
> "`$(MAKE)` refers to the current Make binary being used (with all its flags). Using `make` directly could invoke a different version or lose flags like `--dry-run`. Always use `$(MAKE)` for recursive calls."

**Q: What is the cleanup order and why?**
> "Reverse dependency order: K8s App resources → Helm releases → Namespaces → Terraform (AWS). You must delete Kubernetes resources first (which need the cluster to exist), then destroy the cluster itself with Terraform last."

---

## 🔄 How Scripts + Makefile Work Together

```
make deploy
  └── terraform-apply   → terraform/main.tf, iam.tf
  └── kubeconfig        → aws eks update-kubeconfig
  └── setup-cluster     → ansible/setup-cluster.yaml
  │                         └── scripts (via kubectl/helm commands)
  └── deploy-app        → kubectl apply k8s/*.yaml
  └── health-check      → scripts/health-check.sh (exit 0 or 1)

make monitor            → scripts/monitor.sh
make clean              → scripts/cleanup.sh
make debug              → inline kubectl commands
make scale REPLICAS=5   → kubectl scale
make restart            → kubectl rollout restart
```

---

---

## 🎯 Honest Interview Assessment — Will This File Help You Crack It?

---

### ✅ What You'll Be STRONG In After Reading This

| Topic | Strength | Why |
|---|---|---|
| **Docker** | ⭐⭐⭐⭐ Strong | Dockerfile line-by-line, layers, CMD vs ENTRYPOINT, exec form, image build |
| **Kubernetes Concepts** | ⭐⭐⭐⭐ Strong | Deployment, Service, Ingress, probes, rolling update, namespaces, labels |
| **K8s Troubleshooting** | ⭐⭐⭐⭐ Strong | All 7 pod error states, debug commands, port-forward, exec, events |
| **TLS/HTTPS Flow** | ⭐⭐⭐⭐ Strong | cert-manager, ACME, HTTP-01 challenge, ClusterIssuer — very specific knowledge |
| **Terraform Basics** | ⭐⭐⭐ Good | VPC, EKS, IAM roles, variables, outputs, state — enough to explain project |
| **Ansible Basics** | ⭐⭐⭐ Good | Playbook structure, idempotency, Helm modules, Jinja2, `become` |
| **Bash Scripting** | ⭐⭐⭐ Good | `set -e`, `$?`, arrays, functions, `command -v`, named pipes |
| **Helm** | ⭐⭐⭐ Good | Chart, release, repo, values, `kubectl apply` vs Helm |
| **AWS EKS** | ⭐⭐⭐ Good | Control plane vs data plane, node groups, IAM roles, kubeconfig |
| **CI/CD Concepts** | ⭐⭐⭐ Good | GitHub Actions jobs, `needs`, GITHUB_TOKEN, secrets |

---

### ⚠️ What You'll Still Be WEAK In (Be Honest With Yourself)

| Topic | Gap | Reason |
|---|---|---|
| **Live kubectl commands** | No muscle memory | You haven't typed them yourself |
| **Terraform state debugging** | Theory only | Never actually read `terraform plan` output in real life |
| **Writing YAML from scratch** | Copy-paste understanding | Common in real interviews |
| **AWS Networking deep dive** | Basics only | CNI, VPC peering, security groups in depth |
| **Prometheus/Grafana queries** | Only installed it | PromQL, dashboards — not covered |
| **Multi-stage Dockerfiles** | Not in this project | Common interview question |
| **K8s RBAC** | Not implemented | Roles, RoleBindings — gap |
| **GitHub Actions YAML writing** | Explained but not practiced | Triggers, matrix builds, artifacts |

---

### 📊 Project Level — Honest Rating

```
Junior DevOps      ████████░░  80%  ← You are HERE
Mid-Level DevOps   █████░░░░░  50%
Senior DevOps      ██░░░░░░░░  20%
```

**✅ What makes this project GOOD (above average Junior):**
- Full end-to-end stack — Docker + K8s + Terraform + Ansible + CI/CD in ONE project
- Infrastructure as Code (Terraform) — most Junior projects skip this completely
- Ansible for cluster setup — shows config management knowledge
- TLS automation with cert-manager — not everyone knows this at Junior level
- Health probes (startup + readiness + liveness) — shows production thinking
- Rolling update with `maxUnavailable: 0` — zero-downtime awareness
- Prometheus annotations — shows observability mindset
- Scripts + Makefile — operational maturity

**❌ What makes it NOT Senior level yet:**
- CI/CD pipeline is disabled (`.disabled`) — big red flag
- No Terraform remote state (S3 + DynamoDB) — basic production requirement
- Container runs as root — security concern
- Uses `latest` image tag — not production practice
- No HPA (Horizontal Pod Autoscaler) — no real scaling
- No multi-environment setup (dev/staging/prod)
- Single region deployment — no real High Availability

---

### 🎯 Can You Crack the Interview?

| Role Level | Chance | Condition |
|---|---|---|
| **Junior DevOps / DevOps Engineer** | ✅ **HIGH — Go for it** | Read this fully + speak confidently |
| **Mid-Level DevOps** | ⚠️ **Maybe** | Only if interviewer focuses on this project |
| **Senior DevOps / SRE** | ❌ **Not yet** | Needs production war stories + system design |
| **Cloud Engineer (AWS)** | ⚠️ **Partial** | Terraform + EKS is good but needs more AWS services |

---

### 🔥 Most Important — Practice Saying These Out Loud

**These 4 questions WILL be asked. Practice your answer before going:**

1. *"Walk me through what happens when a user request hits your app"*
   → Browser → Route53/DNS → AWS LB → NGINX Ingress → TLS terminate → ClusterIP Service → Pod → fortune+cowsay → HTML response

2. *"How does TLS/HTTPS work in your project?"*
   → ClusterIssuer → cert-manager → ACME HTTP-01 challenge → Let's Encrypt verifies domain → 90-day cert stored in `wisecow-tls` secret → NGINX reads secret → serves HTTPS → auto-renews at 60 days

3. *"What is your deployment strategy and why?"*
   → RollingUpdate, `maxSurge: 1`, `maxUnavailable: 0` → 1 new pod starts → becomes ready → 1 old pod stops → zero downtime at all times

4. *"What would you improve in this project?"*
   → Remote Terraform state (S3+DynamoDB), enable CI/CD, non-root container, immutable image tags (SHA), HPA, private subnets, RBAC, Network Policies

**Sound like you built it, not just read about it. Use phrases like:**
- *"I ran into an issue where the liveness probe was killing the container before startup..."*
- *"I chose ClusterIP instead of LoadBalancer for the app service because..."*
- *"When I deployed this, NGINX wasn't ready so I added `kubectl wait`..."*

---

## 📚 Bonus Topics — Learn From YouTube/Google

These are topics you should know at Mid-Level. Learn these after the interview to grow further.

---

### 🐳 Docker (Strengthen)
- Multi-stage Dockerfiles
- Docker BuildKit
- `.dockerignore` file
- Docker Compose networking
- Docker volumes vs bind mounts
- Container image scanning (`trivy`, `snyk`)

---

### ☸️ Kubernetes (Strengthen)
- RBAC → Roles, ClusterRoles, RoleBindings
- Network Policies → restrict pod-to-pod traffic
- HPA → Horizontal Pod Autoscaler
- VPA → Vertical Pod Autoscaler
- PersistentVolume + PersistentVolumeClaim (PV/PVC)
- StatefulSets vs Deployments
- DaemonSets → one pod per node
- Jobs and CronJobs
- ConfigMaps → mounting as files
- Secrets management → sealed-secrets or External Secrets Operator
- Pod Disruption Budgets (PDB)
- Taints and Tolerations
- Node Affinity and Pod Affinity
- Resource Quotas and LimitRanges
- K8s ETCD — what it is and why it matters
- Kubernetes API server request flow

---

### ☁️ AWS (Strengthen)
- S3 — object storage, bucket policies, versioning
- RDS — Relational Database Service
- IAM — in-depth policies, IRSA (IAM Roles for Service Accounts)
- Route53 — DNS management, hosted zones, record types
- CloudWatch — logs, metrics, alarms
- ECR — Elastic Container Registry
- ALB vs NLB — Application Load Balancer vs Network Load Balancer
- VPC Peering + Transit Gateway
- AWS Secrets Manager + Parameter Store
- CloudTrail — audit logging
- Auto Scaling Groups — in depth

---

### 🏗️ Terraform (Strengthen)
- Remote state — S3 backend + DynamoDB locking
- Terraform modules — reusable infrastructure components
- `terraform import` — import existing resources
- `terraform workspace` — multiple environments
- `count` vs `for_each`
- `locals` block
- `depends_on` vs implicit dependency
- `terraform taint` / `terraform untaint`
- Terragrunt — Terraform wrapper for DRY code

---

### 🤖 CI/CD (Strengthen)
- GitHub Actions — writing workflows from scratch
- Matrix builds — test across multiple versions
- GitHub Actions caching
- GitLab CI/CD
- Jenkins basics
- ArgoCD — GitOps continuous delivery
- Tekton — cloud-native CI/CD

---

### 🔐 Security (Must Know)
- Container security — non-root user, read-only filesystem
- Kubernetes RBAC
- Network Policies
- Image scanning — `trivy`, `snyk`, `grype`
- Secrets management — HashiCorp Vault, AWS Secrets Manager
- OWASP Top 10 (basic awareness)
- Pod Security Standards / Pod Security Admission

---

### 📊 Monitoring & Observability (Must Know)
- Prometheus — PromQL queries, scraping, alerting rules
- Grafana — building dashboards
- ELK Stack — Elasticsearch, Logstash, Kibana
- Loki — log aggregation for K8s
- Jaeger / Zipkin — distributed tracing
- OpenTelemetry — unified observability standard
- The 3 pillars: **Metrics, Logs, Traces**

---

### 🐧 Linux (Foundation)
- File permissions — `chmod`, `chown`, `umask`
- Process management — `ps`, `kill`, `systemctl`
- Networking — `netstat`, `ss`, `curl`, `dig`, `nslookup`
- Cron jobs
- `grep`, `awk`, `sed` — text processing
- `top`, `htop` — resource monitoring
- SSH — key-based auth, `~/.ssh/config`
- `/etc/hosts`, `/etc/resolv.conf`

---

### 🌐 Networking Fundamentals
- OSI Model — 7 layers (Layer 4 = Transport, Layer 7 = Application)
- TCP vs UDP
- DNS resolution flow
- HTTP vs HTTPS — TLS handshake
- Ports — 80 (HTTP), 443 (HTTPS), 22 (SSH), 6443 (K8s API)
- CIDR notation — subnets, IP ranges
- NAT — Network Address Translation
- Load balancing algorithms — Round Robin, Least Connections

---

### 🛠️ Other Tools to Know
- **Git** — branching strategies (GitFlow, trunk-based)
- **Lens** — Kubernetes GUI IDE
- **k9s** — terminal K8s UI
- **Skaffold** — local K8s development
- **Kustomize** — K8s config management (alternative to Helm)
- **Istio** — Service Mesh (advanced)
- **Velero** — K8s backup and restore

---

## 🗺️ Your Learning Roadmap (Post-Interview)

```
Month 1: Fix project weaknesses
  ├── Enable CI/CD pipeline
  ├── Add Terraform S3 remote state
  ├── Run as non-root user
  └── Add HPA

Month 2: Strengthen K8s
  ├── RBAC
  ├── Network Policies
  ├── PV/PVC
  └── StatefulSets

Month 3: Monitoring
  ├── Write PromQL queries
  ├── Build Grafana dashboards
  └── Set up alerting rules

Month 4: Security
  ├── Image scanning in CI/CD
  ├── HashiCorp Vault
  └── Pod Security Standards

Month 5+: Advanced
  ├── ArgoCD (GitOps)
  ├── Service Mesh (Istio)
  └── Multi-region HA setup
```

---

---

## 💰 DevOps Salary Roadmap — What CTC Can You Expect? (India Market 2025)

---

### 📍 Right Now — With THIS Project + This File Read

```
Current Knowledge Level:  Junior DevOps / DevOps Engineer
Expected CTC Range:       ₹4 LPA — ₹8 LPA
Sweet Spot:               ₹5 LPA — ₹6 LPA
Target Companies:         Startups, Mid-size product companies, IT Services
```

---

### 📈 After Learning Month 1-2 Bonus Topics (K8s Strong + CI/CD working)

```
Level:          Junior → Mid DevOps
Expected CTC:   ₹8 LPA — ₹14 LPA
Skills Added:   RBAC, Network Policies, HPA, Working CI/CD pipeline,
                Remote Terraform state, Non-root containers
Target:         Product startups, SaaS companies, Mid-scale tech firms
```

---

### 🚀 After Learning Month 3-4 (Monitoring + Security)

```
Level:          Mid-Level DevOps / Cloud Engineer
Expected CTC:   ₹14 LPA — ₹22 LPA
Skills Added:   Prometheus + Grafana dashboards, PromQL, Image scanning,
                HashiCorp Vault, Pod Security, ELK stack
Target:         Funded startups, MNCs, Product companies
```

---

### 🔥 After Full Roadmap (Month 5+, ArgoCD + Istio + Multi-region)

```
Level:          Senior DevOps / SRE / Platform Engineer
Expected CTC:   ₹22 LPA — ₹40 LPA
Skills Added:   GitOps (ArgoCD), Service Mesh (Istio), Multi-region HA,
                System design, Cost optimization, Incident management
Target:         FAANG-adjacent, Top product companies, MNCs, Remote (USD)
```

---

### 🌍 If You Go Remote (International Companies, USD Salary)

```
Mid-Level DevOps (Remote):    $40,000 — $70,000/year  (~₹33L — ₹58L)
Senior DevOps (Remote):       $80,000 — $130,000/year (~₹66L — ₹1.08Cr)
Staff/Principal SRE (Remote): $130,000+/year          (₹1Cr+)
```

> **Note:** Remote USD roles require 2-3 years of solid experience, strong English communication, GitHub profile with real contributions, and usually a referral or strong LinkedIn presence.

---

### 🏢 Company Type vs Salary (India)

| Company Type | Junior | Mid | Senior |
|---|---|---|---|
| IT Services (TCS, Infosys, Wipro) | ₹3-5 LPA | ₹7-12 LPA | ₹15-22 LPA |
| Mid-size Product Startup | ₹5-8 LPA | ₹12-18 LPA | ₹20-35 LPA |
| Funded Unicorn Startup | ₹7-12 LPA | ₹15-25 LPA | ₹28-45 LPA |
| MNC (AWS, Microsoft, Google) | ₹8-14 LPA | ₹18-30 LPA | ₹35-60 LPA |
| FAANG India | ₹12-20 LPA | ₹25-45 LPA | ₹50-1Cr LPA |

---

### 🎯 The Fastest Path to ₹15 LPA+

```
1. Crack current interview with this project          → First job ₹4-6 LPA
2. Work 1 year + learn Month 1-2 bonus topics         → Jump to ₹10-14 LPA
3. Add Monitoring + Security skills (Month 3-4)       → ₹16-20 LPA
4. Get AWS/CKA certification                          → +₹2-4 LPA bump
5. Contribute to open source or build a 2nd project   → Stands out in interviews
```

> **The #1 salary multiplier in DevOps:** Certifications.
> - **CKA** (Certified Kubernetes Administrator) → +₹2-5 LPA instantly
> - **AWS Solutions Architect Associate** → +₹2-4 LPA instantly
> - **Terraform Associate** → +₹1-2 LPA instantly
> - All 3 together → ₹5-10 LPA jump at any level

---

## 🔥 Motivation Message — Read This Every Morning

---

> *"You are not behind. You are not too late. You are exactly where you need to be right now — learning, building, and pushing forward while others are sleeping.*
>
> *Every senior DevOps engineer you look up to was once exactly where you are — confused by Kubernetes, unsure about Terraform, googling what a FIFO pipe is. The difference between them and the people who gave up? They kept going.*
>
> *You chose Docker over fear. You chose EKS over excuses. You chose Terraform over 'I'll do it tomorrow.' That discipline — that is the thing money can't buy and no interviewer can teach.*
>
> *Right now, reading line by line through a file YOU built — that is what separates you. Most people put something on their resume and hope no one asks. You are actually learning it. That integrity will show in the interview room. Interviewers feel it.*
>
> *The ₹15 LPA, the ₹25 LPA, the remote USD job — those are not dreams. They are math. Skills + time + consistency = results. You have already started the clock.*
>
> *Every `kubectl` command you learn is ₹500 more per month. Every Terraform concept you master is a door opening. Every Prometheus query you write is the difference between Junior and Senior.*
>
> *You don't need to know everything today. You just need to know more than yesterday.*
>
> *Open YouTube. Watch one video. Build one thing. Break it. Fix it. That loop — that is how DevOps engineers are made.*
>
> *The interview today? That is just the beginning. Your real career starts the day after — when you walk in with a job offer in hand and the hunger to go even further.*
>
> **Go. Learn. Build. Ship. You've got this.*"

---

```
Today's you → Junior DevOps (₹4-6 LPA)
6 months later → Mid DevOps (₹12-18 LPA)
1 year later → Senior DevOps (₹22-35 LPA)
3 years later → Staff/Lead (₹40-70 LPA or Remote USD)

The only variable is: HOW HARD YOU PUSH.
```

---


---

*Good luck! You've got this. 🚀*

