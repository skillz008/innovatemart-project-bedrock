#!/bin/bash

set -e

echo "Starting Project Bedrock deployment..."

# Clean up any previous failed deployments
echo "Cleaning up previous deployments..."
cd terraform
terraform destroy -auto-approve || true

# Wait for resources to be cleaned up
sleep 30

# Initialize and deploy infrastructure
echo "Deploying infrastructure with Terraform..."
terraform init -upgrade

# Validate configuration
terraform validate

# Plan and apply
terraform plan -out=plan.out
terraform apply -auto-approve

# Get EKS cluster info
CLUSTER_NAME=$(terraform output -raw cluster_id 2>/dev/null || echo "innovatemart-eks")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null)

echo "Cluster: $CLUSTER_NAME, Region: $AWS_REGION"

# Update kubeconfig
echo "Updating kubeconfig for cluster: $CLUSTER_NAME"
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Verify cluster access
echo "Verifying cluster access..."
kubectl get nodes

# Install AWS Load Balancer Controller (CRITICAL FIX)
echo "Installing AWS Load Balancer Controller..."
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install with service account creation enabled
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=true \
  --set region=$AWS_REGION

# Wait for controller to be ready
echo "Waiting for Load Balancer Controller to be ready..."
sleep 30
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s

# Deploy retail store application
echo "Deploying retail store application..."
cd ../kubernetes
kubectl apply -f retail-store-app.yaml

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod --all --timeout=600s

# Deploy ingress with ALB fix
echo "Deploying Ingress resource..."
kubectl apply -f ingress.yaml

# Get services
echo "Application deployed successfully!"
echo "Services:"
kubectl get services

# Get ingress information
echo -e "\nIngress:"
kubectl get ingress

# Wait for ALB to be provisioned
echo -e "\nWaiting for ALB to be provisioned..."
sleep 60
ALB_URL=$(kubectl get ingress retail-store-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "ALB not ready yet")

if [ "$ALB_URL" != "ALB not ready yet" ]; then
    echo "🎉 Application URL: http://$ALB_URL"
else
    echo "⚠️  ALB is still provisioning. Check with: kubectl get ingress"
fi

echo -e "\nDeployment complete!"
