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
CLUSTER_NAME=$(terraform output -raw cluster_id)
AWS_REGION=$(terraform output -raw aws_region)
VPC_ID=$(terraform output -raw vpc_id)

echo "Cluster: $CLUSTER_NAME, Region: $AWS_REGION, VPC: $VPC_ID"

# Update kubeconfig with retry logic
echo "Updating kubeconfig for cluster: $CLUSTER_NAME"
for i in {1..5}; do
    if aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME; then
        echo "Kubeconfig updated successfully"
        break
    else
        echo "Attempt $i failed, retrying in 10 seconds..."
        sleep 10
    fi
done

# Verify cluster access with retry logic
echo "Verifying cluster access..."
for i in {1..10}; do
    if kubectl get nodes --request-timeout=10s >/dev/null 2>&1; then
        echo "Cluster access verified"
        kubectl get nodes
        break
    else
        echo "Cluster not ready yet, attempt $i/10, waiting 30 seconds..."
        sleep 30
    fi
    if [ $i -eq 10 ]; then
        echo "ERROR: Failed to connect to cluster after 10 attempts"
        exit 1
    fi
done

# Wait for nodes to be ready
echo "Waiting for nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install AWS Load Balancer Controller
echo "Installing AWS Load Balancer Controller..."

# Create service account for load balancer controller
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: $(terraform output -raw load_balancer_controller_role_arn)
EOF

# Install CRDs
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

# Add Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller with retry
for i in {1..3}; do
    if helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
      -n kube-system \
      --set clusterName=$CLUSTER_NAME \
      --set serviceAccount.create=false \
      --set serviceAccount.name=aws-load-balancer-controller \
      --set region=$AWS_REGION \
      --set vpcId=$VPC_ID; then
        echo "Load Balancer Controller installed successfully"
        break
    else
        echo "Helm install attempt $i failed, retrying in 10 seconds..."
        sleep 10
        # Clean up failed release
        helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true
    fi
done

# Wait for load balancer controller to be ready
echo "Waiting for Load Balancer Controller to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s

# Deploy retail store application
echo "Deploying retail store application..."
cd ../kubernetes

# Apply with retry logic
for i in {1..3}; do
    if kubectl apply -f retail-store-app.yaml; then
        echo "Application deployed successfully"
        break
    else
        echo "Deployment attempt $i failed, retrying in 10 seconds..."
        sleep 10
    fi
done

# Wait for services to be created
sleep 30

# Deploy ingress resource
echo "Deploying Ingress resource..."
kubectl apply -f ingress.yaml

# Wait for all pods to be ready with comprehensive checks
echo "Waiting for all pods to be ready..."
for i in {1..30}; do
    READY=$(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -v "Running\ttrue" | wc -l || echo "1")
    if [ "$READY" -eq 0 ]; then
        echo "All pods are ready!"
        break
    else
        echo "Waiting for pods to be ready... ($i/30)"
        kubectl get pods --no-headers | grep -v Running || true
        sleep 10
    fi
    if [ $i -eq 30 ]; then
        echo "WARNING: Some pods may not be fully ready, continuing anyway..."
        # Show problematic pods
        kubectl get pods --field-selector=status.phase!=Running
    fi
done

# Get services
echo "Application deployed successfully!"
echo "Services:"
kubectl get services

# Get ingress information
echo -e "\nIngress:"
kubectl get ingress

# Check load balancer controller logs to ensure it's working
echo -e "\nLoad Balancer Controller logs:"
kubectl logs -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --tail=10

# Get developer credentials
echo -e "\n=== DEVELOPER ACCESS INSTRUCTIONS ==="
echo "Access Key: $(terraform output -raw developer_access_key)"
echo "Secret Key: $(terraform output -raw developer_secret_key)"
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $AWS_REGION"

echo -e "\nTo configure kubectl for developer access:"
echo "aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --profile innovatemart-developer"

echo -e "\nDeveloper can run these read-only commands:"
echo "kubectl get pods"
echo "kubectl logs <pod-name>"
echo "kubectl describe service <service-name>"
echo "kubectl get events"

# Display the ALB URL with retry logic
echo -e "\nWaiting for ALB to be provisioned..."
for i in {1..20}; do
    ALB_URL=$(kubectl get ingress retail-store-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
    if [ -n "$ALB_URL" ] && [ "$ALB_URL" != "null" ]; then
        echo "Application URL: http://$ALB_URL"
        echo "Your retail store application is now live!"
        break
    else
        echo "ALB not ready yet... ($i/20)"
        sleep 15
    fi
done

# Final status check
echo -e "\n=== FINAL DEPLOYMENT STATUS ==="
kubectl get all,ingress
