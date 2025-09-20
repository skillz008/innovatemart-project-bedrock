variable "aws_region" {
  description = "The AWS region to deploy into (e.g., us-east-1)."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project, used for resource naming and tagging."
  type        = string
  default     = "innovatemart-bedrock" # You can change this
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "A list of Availability Zones in the region."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"] # Use AZs from your chosen region
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "cluster_iam_role_dns_suffix" {
  description = "Base domain name for the IAM role (e.g., amazonaws.com)"
  type        = string
  default     = "amazonaws.com"
}

# Output the nameservers so you can configure them with your domain registrar
output "route53_nameservers" {
  description = "The Route53 nameservers for the hosted zone. Configure these with your domain registrar."
  value       = aws_route53_zone.main.name_servers
}

# Variables for Bonus - RDS credentials

# --- General RDS Instance Settings ---
variable "rds_instance_class" {
  type        = string
  description = "The instance type for the RDS databases."
  default     = "db.t3.micro" # Free tier eligible
}

variable "rds_allocated_storage" {
  type        = number
  description = "The allocated storage in gigabytes for the RDS databases."
  default     = 5 # Minimum for MySQL/PostgreSQL
}

variable "db_engine_version" {
  type        = map(string)
  description = "Engine versions for the RDS databases."
  default = {
    postgres = "15.4"  # Specify your desired PostgreSQL version
    mysql    = "8.0.33" # Specify your desired MySQL version
  }
}

variable "db_parameter_group_family" {
  type        = map(string)
  description = "Parameter group families for the RDS databases."
  default = {
    postgres = "postgres15"
    mysql    = "mysql8.0"
  }
}

# --- For ORDERS Service (PostgreSQL) ---
variable "rds_orders_username" {
  type        = string
  description = "Username for the Orders RDS PostgreSQL instance."
  default     = "ordersuser" # For demo only. Use secrets in production.
  sensitive   = true
}
variable "rds_orders_password" {
  type        = string
  description = "Password for the Orders RDS PostgreSQL instance."
  default     = "orderspass123!" # For demo only. Use secrets in production.
  sensitive   = true
}
variable "rds_orders_db_name" {
  type        = string
  description = "Initial database name for the Orders RDS instance."
  default     = "orders"
}

# --- For CATALOG Service (MySQL) ---
variable "rds_catalog_username" {
  type        = string
  description = "Username for the Catalog RDS MySQL instance."
  default     = "cataloguser" # For demo only. Use secrets in production.
  sensitive   = true
}
variable "rds_catalog_password" {
  type        = string
  description = "Password for the Catalog RDS MySQL instance."
  default     = "catalogpass123!" # For demo only. Use secrets in production.
  sensitive   = true
}
variable "rds_catalog_db_name" {
  type        = string
  description = "Initial database name for the Catalog RDS instance."
  default     = "catalog"
}

# --- For CARTS Service (DynamoDB) ---
variable "dynamodb_carts_table_name" {
  type        = string
  description = "Name of the DynamoDB table for the Carts service."
  default     = "Carts" # Note: DynamoDB table names are case-sensitive.
}
variable "dynamodb_carts_billing_mode" {
  type        = string
  description = "DynamoDB billing mode. Can be PROVISIONED or PAY_PER_REQUEST."
  default     = "PAY_PER_REQUEST" # Best for variable/workloads like a cart.
}
variable "dynamodb_carts_hash_key" {
  type        = string
  description = "The name of the hash (partition) key for the Carts table."
  default     = "id"
}
