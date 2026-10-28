variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "private_app_subnet_ids" {
  description = "List of private application subnet IDs where worker nodes reside"
  type        = list(string)
}

variable "eks_nodes_security_group_id" {
  description = "Security Group ID attached to worker nodes"
  type        = string
}

variable "instance_types" {
  description = "EC2 instance types for the node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "capacity_type" {
  description = "Type of capacity associated with the EKS Node Group (ON_DEMAND, SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
}

variable "disk_size" {
  description = "Disk size in GiB for worker node root volumes"
  type        = number
  default     = 50
}

variable "ami_type" {
  description = "Type of Amazon Machine Image (AMI) associated with the EKS Node Group. EKS requires AL2023 for modern versions."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS node group. Must align with cluster version (e.g., 1.34)."
  type        = string
  default     = "1.34"
}
