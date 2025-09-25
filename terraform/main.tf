terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Module with NAT Gateway configuration to avoid EIP limits
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "innovatemart-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  # Use only ONE NAT Gateway to conserve EIPs
  enable_nat_gateway     = true
  single_nat_gateway     = true  # Critical fix: Use single NAT Gateway
  one_nat_gateway_per_az = false # Disable per-AZ NAT gateways
  
  enable_vpn_gateway   = false
  enable_dns_hostnames = true

  tags = {
    Environment = "production"
    Project     = "project-bedrock"
  }
}

# EKS Cluster with enhanced configuration
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "innovatemart-eks"
  cluster_version = "1.28"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] # Allow from anywhere

  # Enable IRSA for better security
  enable_irsa = true

  # Add cluster security group rules for node communication
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Enhanced node group configuration
  eks_managed_node_groups = {
    main = {
      name            = "main"
      min_size        = 1
      max_size        = 3
      desired_size    = 2
      instance_types  = ["t3.medium"]
      capacity_type   = "ON_DEMAND"

      # Use launch template for better control
      use_custom_launch_template = false

      # Disk size
      disk_size = 20

      # Updated IAM role configuration
      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
      }

      # Update configuration to prevent node join issues
      update_config = {
        max_unavailable_percentage = 50
      }

      # Taints and labels
      labels = {
        role = "general"
      }

      tags = {
        Environment = "production"
        Project     = "project-bedrock"
      }
    }
  }

  # Node security group additional rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  tags = {
    Environment = "production"
    Project     = "project-bedrock"
  }
}

# IAM Role for Load Balancer Controller (IRSA)
resource "aws_iam_role" "load_balancer_controller" {
  name = "aws-load-balancer-controller"

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
}

# Load Balancer Controller IAM Policy
resource "aws_iam_policy" "load_balancer_controller" {
  name        = "AWSLoadBalancerController"
  description = "Policy for AWS Load Balancer Controller"

  policy = file("${path.module}/iam-policies/load-balancer-controller.json")
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  policy_arn = aws_iam_policy.load_balancer_controller.arn
  role       = aws_iam_role.load_balancer_controller.name
}

# IAM User for Developers
resource "aws_iam_user" "developer" {
  name = "innovatemart-developer"
  path = "/developers/"
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
          "ec2:DescribeRegions",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_access_key" "developer" {
  user = aws_iam_user.developer.name
}

# Outputs
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster CA certificate"
  value       = module.eks.cluster_certificate_authority_data
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "developer_access_key" {
  description = "Developer IAM access key"
  value       = aws_iam_access_key.developer.id
  sensitive   = true
}

output "developer_secret_key" {
  description = "Developer IAM secret key"
  value       = aws_iam_access_key.developer.secret
  sensitive   = true
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "load_balancer_controller_role_arn" {
  description = "Load Balancer Controller IAM Role ARN"
  value       = aws_iam_role.load_balancer_controller.arn
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
