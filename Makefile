# Makefile for Wisecow Application

# Variables
CLUSTER_NAME ?= wisecow-cluster
AWS_REGION ?= us-east-1
NAMESPACE ?= wisecow
IMAGE_TAG ?= latest
REGISTRY ?= ghcr.io/anuragstark/wisecow

# Colors
YELLOW := \033[1;33m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m

.PHONY: help build deploy clean monitor health-check logs

help: ## Display this help message
	@echo "Wisecow Application Management"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build Docker image
	@echo -e "$(YELLOW)Building Docker image...$(NC)"
	docker build -t $(REGISTRY):$(IMAGE_TAG) .
	@echo -e "$(GREEN)Image built successfully$(NC)"

push: ## Push Docker image to registry
	@echo -e "$(YELLOW)Pushing image to registry...$(NC)"
	docker push $(REGISTRY):$(IMAGE_TAG)
	@echo -e "$(GREEN)Image pushed successfully$(NC)"

terraform-init: ## Initialize Terraform
	@echo -e "$(YELLOW)Initializing Terraform...$(NC)"
	cd terraform && terraform init
	@echo -e "$(GREEN)Terraform initialized$(NC)"

terraform-plan: ## Plan Terraform deployment
	@echo -e "$(YELLOW)Planning Terraform deployment...$(NC)"
	cd terraform && terraform plan
	@echo -e "$(GREEN)Terraform plan completed$(NC)"

terraform-apply: ## Apply Terraform configuration
	@echo -e "$(YELLOW)Applying Terraform configuration...$(NC)"
	cd terraform && terraform apply -auto-approve
	@echo -e "$(GREEN)Infrastructure deployed$(NC)"

terraform-destroy: ## Destroy Terraform infrastructure
	@echo -e "$(YELLOW)Destroying Terraform infrastructure...$(NC)"
	cd terraform && terraform destroy -auto-approve
	@echo -e "$(GREEN)Infrastructure destroyed$(NC)"

kubeconfig: ## Update kubeconfig
	@echo -e "$(YELLOW)Updating kubeconfig...$(NC)"
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)
	@echo -e "$(GREEN)Kubeconfig updated$(NC)"

setup-cluster: ## Setup cluster components with Ansible
	@echo -e "$(YELLOW)Setting up cluster components...$(NC)"
	ansible-playbook ansible/setup-cluster.yaml --ask-become-pass
	@echo -e "$(GREEN)Cluster setup completed$(NC)"

deploy-app: ## Deploy application to Kubernetes
	@echo -e "$(YELLOW)Deploying application...$(NC)"
	kubectl apply -f k8s/deployment.yaml
	kubectl apply -f k8s/service.yaml
	kubectl apply -f k8s/cluster-issuer.yaml
	kubectl apply -f k8s/ingress.yaml
	@echo -e "$(GREEN)Application deployed$(NC)"

deploy: terraform-apply kubeconfig setup-cluster deploy-app ## Full deployment (infrastructure + application)
	@echo -e "$(GREEN)Full deployment completed$(NC)"
	@$(MAKE) health-check

clean: ## Clean up all resources
	@echo -e "$(YELLOW)Cleaning up resources...$(NC)"
	./scripts/cleanup.sh
	@echo -e "$(GREEN)Cleanup completed$(NC)"

monitor: ## Monitor application status
	@echo -e "$(YELLOW)Monitoring application...$(NC)"
	./scripts/monitor.sh

health-check: ## Perform health check
	@echo -e "$(YELLOW)Performing health check...$(NC)"
	./scripts/health-check.sh

logs: ## View application logs
	@echo -e "$(YELLOW)Viewing application logs...$(NC)"
	kubectl logs -f deployment/wisecow-deployment -n $(NAMESPACE)

scale: ## Scale application (usage: make scale REPLICAS=5)
	@echo -e "$(YELLOW)Scaling application to $(REPLICAS) replicas...$(NC)"
	kubectl scale deployment wisecow-deployment --replicas=$(REPLICAS) -n $(NAMESPACE)
	@echo -e "$(GREEN)Application scaled$(NC)"

restart: ## Restart application
	@echo -e "$(YELLOW)Restarting application...$(NC)"
	kubectl rollout restart deployment/wisecow-deployment -n $(NAMESPACE)
	kubectl rollout status deployment/wisecow-deployment -n $(NAMESPACE)
	@echo -e "$(GREEN)Application restarted$(NC)"

status: ## Show application status
	@echo -e "$(YELLOW)Application Status:$(NC)"
	kubectl get pods,svc,ingress -n $(NAMESPACE)

get-url: ## Get application URL
	@echo -e "$(YELLOW)Getting application URL...$(NC)"
	@LB_URL=$$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'); \
	if [ -n "$$LB_URL" ]; then \
		echo -e "$(GREEN)Application URL: http://$$LB_URL$(NC)"; \
	else \
		echo -e "$(RED)LoadBalancer URL not available$(NC)"; \
	fi

debug: ## Debug application issues
	@echo -e "$(YELLOW)Debug Information:$(NC)"
	@echo "--- Pods ---"
	kubectl get pods -n $(NAMESPACE) -o wide
	@echo "--- Events ---"
	kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -10
	@echo "--- Pod Logs ---"
	kubectl logs -l app=wisecow -n $(NAMESPACE) --tail=50

test: ## Test application endpoint
	@echo -e "$(YELLOW)Testing application endpoint...$(NC)"
	@LB_URL=$$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'); \
	if [ -n "$$LB_URL" ]; then \
		curl -v "http://$$LB_URL"; \
	else \
		echo -e "$(RED)LoadBalancer URL not available$(NC)"; \
	fi

install-tools: ## Install required tools
	@echo -e "$(YELLOW)Installing required tools...$(NC)"
	# Install kubectl
	curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	chmod +x kubectl
	sudo mv kubectl /usr/local/bin/
	# Install helm
	curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
	# Install terraform
	wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
	echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
	sudo apt update && sudo apt install terraform
	@echo -e "$(GREEN)Tools installed$(NC)"

# Default target
all: deploy