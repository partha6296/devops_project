project_name = "cloudops-taskapp"
environment  = "dev"
aws_region   = "us-east-1"

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
private_db_subnet_cidrs  = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

single_nat_gateway   = true  # Cost optimization for dev (1 NAT GW instead of 3)
enable_vpc_endpoints = false # Set false in dev to avoid ~$100/mo interface endpoint costs; NAT GW provides outbound connectivity

cluster_version    = "1.34"
eks_instance_types = ["t3.small"]
eks_ami_type       = "AL2023_x86_64_STANDARD"
eks_desired_size   = 2
eks_min_size       = 2
eks_max_size       = 4

db_name                    = "taskmanagement"
db_username                = "postgresadmin"
db_instance_class          = "db.t4g.micro" # AWS Free Tier eligible (750 hours/month)
db_multi_az                = false          # Single AZ for dev
db_backup_retention_period = 1              # Maximum allowed under AWS Free Tier accounts
db_port                    = 5432

# Note: Dev runs without custom domains, ACM, or Route 53.
# Traffic is served directly via CloudFront default HTTPS domain (*.cloudfront.net)
