output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster."
  value       = module.eks.cluster_security_group_id
}

# This is crucial for the developer access instructions
output "developer_ro_access_key_id" {
  description = "The access key ID for the read-only developer user."
  value       = aws_iam_access_key.developer_ro.id
  sensitive   = true
}

output "developer_ro_secret_access_key" {
  description = "The secret access key for the read-only developer user. SAVE THIS SECURELY."
  value       = aws_iam_access_key.developer_ro.secret
  sensitive   = true
}

# Output for the UI service URL (useful for core requirement)
# output "ui_service_url" {
#  description = "The URL for the UI service."
#  value       = "http://${kubernetes_service_v1.ui.status.0.load_balancer.0.ingress.0.hostname}"
  # Note: This output requires a kubernetes provider resource defined for the UI service, which is more advanced.
  # A simpler alternative is to just get this using 'kubectl get svc ui' after deployment.
# }
