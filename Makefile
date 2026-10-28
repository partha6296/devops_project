# ==============================================================================
# CloudOps TaskApp - DevOps Automation Makefile
# ==============================================================================
SHELL := /bin/bash
ENV ?= dev
TF_DIR := terraform/environments/$(ENV)

.PHONY: help deploy-frontend tf-init tf-plan tf-apply tf-destroy k8s-login app-status monitoring-status grafana-tunnel prometheus-tunnel loki-tunnel argocd-tunnel

help: ## Show this help message
	@echo "======================================================================="
	@echo "🛠️  CloudOps TaskApp - Platform Management Commands [ENV=$(ENV)]"
	@echo "======================================================================="
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo "======================================================================="

## --- Frontend Deployment ---

deploy-frontend: ## Sync static UI to S3 and invalidate CloudFront CDN cache
	@./scripts/deploy-frontend.sh $(ENV)

## --- Infrastructure as Code (Terraform) ---

tf-init: ## Initialize Terraform providers and backend for selected ENV (default: dev)
	@cd $(TF_DIR) && terraform init

tf-plan: ## Run terraform plan for selected ENV
	@cd $(TF_DIR) && terraform plan

tf-apply: ## Run terraform apply for selected ENV
	@cd $(TF_DIR) && terraform apply

tf-destroy: ## Tear down Terraform infrastructure for selected ENV
	@cd $(TF_DIR) && terraform destroy

tf-output: ## Display all output variables from Terraform
	@cd $(TF_DIR) && terraform output

## --- Kubernetes & Cluster Management ---

k8s-login: ## Configure local kubectl context for the EKS cluster
	@command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required."; exit 1; }
	@CLUSTER_NAME=$$(cd $(TF_DIR) && terraform output -raw cluster_name 2>/dev/null || echo "cloudops-taskapp-$(ENV)-eks"); \
	REGION=$$(cd $(TF_DIR) && terraform output -raw aws_region 2>/dev/null || echo "us-east-1"); \
	echo "🔑 Updating kubeconfig for cluster: $$CLUSTER_NAME in $$REGION..."; \
	aws eks --region $$REGION update-kubeconfig --name $$CLUSTER_NAME

app-status: ## Check the status of microservice pods, services, and ingress
	@echo "📋 Microservices in namespace [taskapp-$(ENV)]:"
	@kubectl get pods,svc,ingress,hpa -n taskapp-$(ENV) -o wide 2>/dev/null || echo "Namespace taskapp-$(ENV) not active yet."

connect-alb: ## Register running frontend pod IP into the ALB target group
	@echo "🔗 Connecting frontend pod to ALB target group..."
	@TG_ARN=$$(aws elbv2 describe-target-groups --names cloudops-taskapp-$(ENV)-default-tg --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null); \
	POD_IP=$$(kubectl get pod -n taskapp-$(ENV) -l app.kubernetes.io/name=frontend -o jsonpath='{.items[0].status.podIP}' 2>/dev/null); \
	if [ -z "$$POD_IP" ]; then echo "❌ Frontend pod not running yet. Run 'make app-status' to check."; exit 1; fi; \
	echo "Found Frontend Pod IP: $$POD_IP"; \
	echo "Target Group: $$TG_ARN"; \
	aws elbv2 register-targets --target-group-arn $$TG_ARN --targets Id=$$POD_IP,Port=3000; \
	echo "✅ Successfully registered frontend pod ($$POD_IP:3000) to ALB target group!"

monitoring-status: ## Check the status of Prometheus, Grafana, Loki & Promtail
	@echo "📊 Observability stack in namespace [monitoring]:"
	@kubectl get pods,svc,daemonset -n monitoring -o wide 2>/dev/null || echo "Namespace monitoring not active yet."

## --- Observability Port-Forward Tunnels ---

grafana-tunnel: ## Port-forward Grafana dashboard to http://localhost:3000
	@echo "📈 Opening Grafana at http://localhost:3000 (Ctrl+C to stop)..."
	@kubectl port-forward -n monitoring svc/grafana 3000:3000

prometheus-tunnel: ## Port-forward Prometheus expression browser to http://localhost:9090
	@echo "🔥 Opening Prometheus at http://localhost:9090 (Ctrl+C to stop)..."
	@kubectl port-forward -n monitoring svc/prometheus 9090:9090

loki-tunnel: ## Port-forward Loki log endpoint to http://localhost:3100
	@echo "🪵 Opening Loki at http://localhost:3100 (Ctrl+C to stop)..."
	@kubectl port-forward -n monitoring svc/loki 3100:3100

argocd-tunnel: ## Port-forward Argo CD dashboard to https://localhost:8080
	@echo "🐙 Opening Argo CD at https://localhost:8080 (Ctrl+C to stop)..."
	@kubectl port-forward -n argocd svc/argocd-server 8080:443
