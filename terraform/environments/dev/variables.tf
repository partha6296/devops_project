variable "project_name" {
  description = "Project name"
  type        = string
  default     = "cloudops-taskapp"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "us-east-1"
}

# --- Networking ---
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets (EKS nodes/workloads)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private database subnets (RDS)"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
}

variable "single_nat_gateway" {
  description = "Deploy a single NAT gateway to save costs in non-production"
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "Whether to provision VPC Endpoints"
  type        = bool
  default     = true
}

# --- EKS ---
variable "cluster_version" {
  description = "EKS Kubernetes version (supported: 1.34, 1.35, 1.36, 1.37)"
  type        = string
  default     = "1.34"
}

variable "eks_instance_types" {
  description = "Instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_ami_type" {
  description = "AMI Type for EKS node group (EKS 1.30+ requires AL2023)"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "eks_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
}

variable "cluster_log_types" {
  description = "Desired control plane logging types to enable in EKS (empty for dev/free tier to avoid logging costs)"
  type        = list(string)
  default     = []
}

variable "create_eks_log_group" {
  description = "Whether to create CloudWatch log group for EKS control plane in Terraform"
  type        = bool
  default     = false
}

# --- Database ---
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "taskmanagement"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "postgresadmin"
}

variable "db_instance_class" {
  description = "RDS database instance class (db.t4g.micro is Free Tier eligible)"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_multi_az" {
  description = "Whether to enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days (1 day maximum for AWS Free Tier accounts)"
  type        = number
  default     = 1
}

variable "db_port" {
  description = "Database port (5432 for Postgres)"
  type        = number
  default     = 5432
}

# --- ECR ---
variable "ecr_repository_names" {
  description = "List of ECR repository names"
  type        = list(string)
  default = [
    "taskapp-user-service",
    "taskapp-task-service",
    "taskapp-notification-service",
    "taskapp-frontend"
  ]
}

# --- End of Dev Variables ---
