terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "innovatemart-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true

  tags = {
    Environment = "production"
    Project     = "project-bedrock"
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "innovatemart-eks"
  cluster_version = "1.28"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    main = {
      name           = "main"
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }
    }
  }

  tags = {
    Environment = "production"
    Project     = "project-bedrock"
  }
}

# IAM User for Developers
resource "aws_iam_user" "developer" {
  name = "innovatemart-developer"
  path = "/developers/"

  lifecycle {
    prevent_destroy = true
    ignore_changes = [name]
  }
}

resource "aws_iam_user_policy" "developer_readonly" {
  name = "EKSReadOnlyAccess"
  user = aws_iam_user.developer.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:ListFargateProfiles",
          "eks:ListNodegroups",
          "eks:ListUpdates"
        ]
        Resource = module.eks.cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      }
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_access_key" "developer" {
  user = aws_iam_user.developer.name

  lifecycle {
    prevent_destroy = true
  }
}

# IAM Role for Load Balancer Controller
resource "aws_iam_role" "load_balancer_controller" {
  name = "AmazonEKSLoadBalancerControllerRole"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
    Version = "2012-10-17"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes = [name]
  }
}

# Load Balancer Controller IAM Policy
resource "aws_iam_policy" "load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for AWS Load Balancer Controller"

  policy = file("${path.module}/iam-policies/load-balancer-controller.json")

  lifecycle {
    prevent_destroy = true
    ignore_changes = [name]
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  policy_arn = aws_iam_policy.load_balancer_controller.arn
  role       = aws_iam_role.load_balancer_controller.name

  lifecycle {
    prevent_destroy = true
  }
}

# Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "load_balancer_controller_role_arn" {
  description = "Load Balancer Controller IAM Role ARN"
  value       = aws_iam_role.load_balancer_controller.arn
}
