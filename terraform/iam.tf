# Read-only developer user
resource "aws_iam_user" "developer_ro" {
  name = "${var.project_name}-developer-ro"
  path = "/"
}

resource "aws_iam_user_policy_attachment" "developer_ro" {
  user       = aws_iam_user.developer_ro.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Policy to allow the user to get-token for the specific EKS cluster
resource "aws_iam_policy" "eks_get_token" {
  name        = "${var.project_name}-EKSGetToken"
  description = "Allows getting a token for the InnovateMart EKS cluster"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "eks:DescribeCluster",
        Resource = module.eks.cluster_arn
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "developer_ro_eks" {
  user       = aws_iam_user.developer_ro.name
  policy_arn = aws_iam_policy.eks_get_token.arn
}

# Generate and store access keys for the user
resource "aws_iam_access_key" "developer_ro" {
  user = aws_iam_user.developer_ro.name
}
