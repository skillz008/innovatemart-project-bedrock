#!/bin/bash

# This script shows how developers should configure their environment

echo "Developer Access Configuration for InnovateMart EKS Cluster"

cat << EOF

1. Install required tools:
   - AWS CLI: https://aws.amazon.com/cli/
   - kubectl: https://kubernetes.io/docs/tasks/tools/

2. Configure AWS credentials:
   aws configure set aws_access_key_id YOUR_ACCESS_KEY
   aws configure set aws_secret_access_key YOUR_SECRET_KEY
   aws configure set region us-east-1

3. Update kubeconfig:
   aws eks update-kubeconfig --region us-east-1 --name innovatemart-eks

4. Test access:
   kubectl get pods
   kubectl get services

5. Useful read-only commands:
   - View pods: kubectl get pods
   - View logs: kubectl logs <pod-name>
   - Describe service: kubectl describe service <service-name>
   - View events: kubectl get events

Note: Developer access is read-only. Modification operations will be denied.
EOF
