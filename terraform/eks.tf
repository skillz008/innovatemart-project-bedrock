module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "${var.project_name}-cluster"
  cluster_version = "1.28"

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Core IAM Role for the Cluster itself
  cluster_iam_role_dns_suffix = var.cluster_iam_role_dns_suffix
  create_iam_role             = true
  iam_role_name               = "${var.project_name}-cluster-role"

  # EKS Managed Node Group
  eks_managed_node_groups = {
    main = {
      name           = "${var.project_name}-nodegroup"
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2

      # IAM Role for the Node Group
      create_iam_role = true
      iam_role_name   = "${var.project_name}-nodegroup-role"
    }
  }

  tags = {
    Project = var.project_name
  }
}
