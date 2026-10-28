# Complete End-to-End Deployment Guide

This guide walks you through deploying the complete **CloudOps TaskApp** platform from scratch on AWS:
- **Terraform IaC**: VPC, Subnets, EKS 1.34, RDS PostgreSQL (Free Tier), S3, CloudFront, ALB, ECR, Secrets Manager.
- **Microservices**: Node.js microservices (`user-service`, `task-service`, `notification-service`, `frontend`).
- **GitOps with Argo CD**: Self-healing automated continuous deployment.
- **Observability**: Prometheus, Grafana, Loki, and Promtail.
- **Frontend Delivery**: High-speed global delivery via CloudFront + S3 with zero domain costs.

---

## 📋 Table of Contents
1. [Prerequisites](#1-prerequisites)
2. [Step 1: Configure AWS CLI & State Backend](#step-1-configure-aws-cli--state-backend)
3. [Step 2: Provision AWS Infrastructure via Terraform](#step-2-provision-aws-infrastructure-via-terraform)
4. [Step 3: Connect kubectl to EKS Cluster](#step-3-connect-kubectl-to-eks-cluster)
5. [Step 4: Build & Push Docker Images to Amazon ECR](#step-4-build--push-docker-images-to-amazon-ecr)
6. [Step 5: Bootstrap Argo CD & GitOps Platform](#step-5-bootstrap-argo-cd--gitops-platform)
7. [Step 6: Deploy Frontend to S3 & Invalidate CloudFront](#step-6-deploy-frontend-to-s3--invalidate-cloudfront)
8. [Step 7: Verify Application & Observability Dashboards](#step-7-verify-application--observability-dashboards)
9. [Step 8: Teardown & Clean Up](#step-8-teardown--clean-up)

---

## 1. Prerequisites

Ensure you have the following CLI tools installed:
* **AWS CLI** (`aws --version` >= 2.15)
* **Terraform** (`terraform --version` >= 1.5)
* **kubectl** (`kubectl version --client` >= 1.30)
* **Docker** (`docker --version` >= 24)
* **make** (`make --version`)

---

## Step 1: Configure AWS CLI & State Backend

### 1.1 Configure your AWS credentials
```bash
aws configure
# Verify your identity and permissions
aws sts get-caller-identity
```

### 1.2 Create S3 Bucket & DynamoDB Table for Terraform State
The `dev` backend is configured to store remote state safely in S3 with DynamoDB state locking:

```bash
# Create the S3 bucket (Region: us-east-1)
aws s3api create-bucket \
  --bucket taskapp-terraform-state-dev \
  --region us-east-1

# Enable versioning on the state bucket
aws s3api put-bucket-versioning \
  --bucket taskapp-terraform-state-dev \
  --versioning-configuration Status=Enabled

# Create the DynamoDB table for state locking
aws dynamodb create-table \
  --table-name taskapp-terraform-locks-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## Step 2: Provision AWS Infrastructure via Terraform

### 2.1 Initialize and Apply Terraform
Navigate to the `dev` environment and apply:

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```
*(Or from the project root using our Makefile: `make tf-apply`)*

> [!NOTE]
> Provisioning the EKS 1.34 cluster and RDS database typically takes **10–15 minutes**.

### 2.2 Inspect the Outputs
Once apply completes, note down the output values:
```bash
terraform output
```
Key outputs:
- `cluster_name`: `cloudops-taskapp-dev-eks`
- `cloudfront_domain_name`: `dXXXXXXXXXXXXX.cloudfront.net`
- `frontend_s3_bucket`: `cloudops-taskapp-dev-frontend-XXXXXX`
- `alb_dns_name`: `cloudops-taskapp-dev-alb-XXXXXX.us-east-1.elb.amazonaws.com`

---

## Step 3: Connect kubectl to EKS Cluster

Update your local kubeconfig context to authenticate with the EKS cluster:

```bash
# From project root:
make k8s-login
# Or manually:
aws eks --region us-east-1 update-kubeconfig --name cloudops-taskapp-dev-eks
```

Verify that the EKS worker nodes are online and in `Ready` status:
```bash
kubectl get nodes
```

---

## Step 4: Build & Push Docker Images to Amazon ECR

### 4.1 Authenticate Docker with Amazon ECR
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
```

### 4.2 Build, Tag, and Push All Microservices
```bash
SERVICES=("user-service" "task-service" "notification-service" "frontend")

for SVC in "${SERVICES[@]}"; do
  echo "🚀 Building and pushing ${SVC}..."
  docker build -t ${ECR_REGISTRY}/taskapp-${SVC}:latest -f app/services/${SVC}/Dockerfile app/services/${SVC}
  docker push ${ECR_REGISTRY}/taskapp-${SVC}:latest
done
```

### 4.3 Update Helm Values with Your ECR Registry
Open the dev values files and ensure `image.repository` points to your ECR registry:
- `gitops/environments/dev/user-service-values.yaml` -> `repository: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/taskapp-user-service`
- `gitops/environments/dev/task-service-values.yaml` -> `repository: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/taskapp-task-service`
- `gitops/environments/dev/notification-service-values.yaml` -> `repository: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/taskapp-notification-service`
- `gitops/environments/dev/frontend-values.yaml` -> `repository: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/taskapp-frontend`

Commit and push this change to your Git repository:
```bash
git add gitops/environments/dev/
git commit -m "chore: update ECR image repository to account $ACCOUNT_ID"
git push origin main
```

---

## Step 5: Bootstrap Argo CD & GitOps Platform

### 5.1 Install Argo CD onto the EKS Cluster
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait until Argo CD Server is available
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### 5.2 Retrieve the Initial Argo CD Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### 5.3 Verify Git Repository URL
In `gitops/argo-apps/root-application.yaml`, ensure the `repoURL` points to your GitHub repository:
```yaml
spec:
  source:
    repoURL: 'https://github.com/partha6296/devops_project.git'
```

### 5.4 Deploy the Root App-of-Apps
```bash
kubectl apply -f gitops/argo-apps/root-application.yaml
```

Argo CD will automatically orchestrate the full deployment lifecycle:
- **Wave 0**: Observability Stack (Prometheus, Grafana, Loki, Promtail) + Metrics Server
- **Wave 1**: PostgreSQL Database in `taskapp-dev`
- **Wave 2**: User Service & Notification Service
- **Wave 3**: Task Service
- **Wave 4**: Frontend API Gateway & Ingress

### 5.5 Check Application Status
```bash
make app-status
make monitoring-status
```

---

## Step 6: Deploy Frontend to S3 & Invalidate CloudFront

Upload the frontend single-page application to the private S3 bucket and trigger a CloudFront edge cache refresh with one command:

```bash
make deploy-frontend
```

This script:
1. Queries Terraform for the `frontend_s3_bucket` and `cloudfront_distribution_id`.
2. Syncs `app/services/frontend/public/` to S3 with cache-control headers (`no-cache` for HTML, long-lived for static assets).
3. Submits an invalidation (`/*`) to CloudFront.
4. Prints your live `https://dXXXX.cloudfront.net` URL.

---

## Step 7: Verify Application & Observability Dashboards

### 7.1 Access the Application
Open the CloudFront URL printed by `make deploy-frontend` or:
```bash
cd terraform/environments/dev && terraform output cloudfront_domain_name
```
Navigate to:
```text
https://dXXXXXXXXXXXXX.cloudfront.net
```
**Test actions in the Web UI**:
1. Create a User (e.g. `John Doe`, `john@example.com`) -> Saved to PostgreSQL.
2. Create a Task assigned to the user -> Real-time task board updates.
3. Check Notification feed -> Verify simulator events.

---

### 7.2 Access Grafana Dashboards (Metrics & Logs)
```bash
make grafana-tunnel
```
- Open [http://localhost:3000](http://localhost:3000)
- **Login**: `admin` / `admin123` (Anonymous admin access is also enabled)
- Navigate to **Dashboards > Microservices & Cluster**:
  - **TaskApp - Microservices Overview**: Real-time HTTP requests/sec, error rate %, 2xx/4xx/5xx status codes, and correlated live application logs.
  - **TaskApp - Cluster Resources & Health**: CPU and Memory consumption per pod, container, and namespace.

---

### 7.3 Access Prometheus Expression Browser
```bash
make prometheus-tunnel
```
- Open [http://localhost:9090](http://localhost:9090)
- Check **Status > Targets** to verify all microservices and nodes are reporting `UP`.

---

### 7.4 Access the Argo CD Web Console
```bash
make argocd-tunnel
```
- Open [https://localhost:8080](https://localhost:8080)
- **Username**: `admin`
- **Password**: retrieved in Step 5.2

---

## Step 8: Teardown & Clean Up

To avoid ongoing AWS charges when you are done testing:

### 8.1 Delete Kubernetes Workloads
```bash
kubectl delete -f gitops/argo-apps/root-application.yaml
```

### 8.2 Empty the Frontend S3 Bucket
AWS prevents deleting non-empty S3 buckets:
```bash
BUCKET_NAME=$(cd terraform/environments/dev && terraform output -raw frontend_s3_bucket)
aws s3 rm s3://${BUCKET_NAME} --recursive
```

### 8.3 Destroy AWS Infrastructure
```bash
make tf-destroy
```
Confirm with `yes` when prompted. Terraform will cleanly deprovision the VPC, EKS cluster, worker nodes, RDS database, ALB, S3 buckets, and CloudFront distribution.
