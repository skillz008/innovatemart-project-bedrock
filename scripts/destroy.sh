#!/bin/bash

set -e

echo "Cleaning up Project Bedrock deployment..."

cd terraform

# Destroy Kubernetes resources first
echo "Deleting Kubernetes resources..."
kubectl delete -f ../kubernetes/ --ignore-not-found=true || true
kubectl delete ingress retail-store-ingress --ignore-not-found=true || true

# Uninstall load balancer controller
helm uninstall aws-load-balancer-controller -n kube-system --ignore-not-found=true || true

# Destroy Terraform infrastructure
echo "Destroying Terraform infrastructure..."
terraform destroy -auto-approve

echo "Cleanup completed successfully!"
