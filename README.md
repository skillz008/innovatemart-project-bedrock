
# InnovateMart – Project Bedrock 🚀

**Production-Grade Kubernetes Deployment on AWS EKS**

---

## 📌 Project Overview

InnovateMart Inc. is a rapidly growing e-commerce startup that has recently transitioned from a monolithic architecture to modern microservices. This project, **Project Bedrock**, lays the foundation for InnovateMart’s global-scale infrastructure by deploying the **Retail Store Sample Application** to **Amazon Elastic Kubernetes Service (EKS)**.

As the Cloud DevOps Engineer, I designed, automated, and delivered this environment with **automation, security, and scalability** as core principles.

---

## 🎯 Mission Objectives

1. **Infrastructure as Code (IaC):**

   * Provision AWS infrastructure using **Terraform** (recommended).
   * Create:

     * A **VPC** with public and private subnets.
     * An **EKS cluster** with worker nodes.
     * Required **IAM roles and policies** for the cluster and node groups.

2. **Application Deployment:**

   * Deploy the **retail-store-sample-app** to the EKS cluster.
   * Use in-cluster dependencies for this phase (MySQL, PostgreSQL, Redis, RabbitMQ, DynamoDB Local).

3. **Developer Access:**

   * Provision an **IAM user** with **read-only access** to EKS resources.
   * Provide credentials and kubeconfig setup instructions.

4. **Automation (CI/CD):**

   * Implement a **CI/CD pipeline** using **GitHub Actions**.
   * Branching strategy:

     * `feature/*` → runs `terraform plan`.
     * `main` → runs `terraform apply`.
   * Manage AWS credentials securely (no hardcoding).

5. ** **Networking Enhancements:**

  * Install **AWS Load Balancer Controller**.
  * Configure **Ingress** with ALB to expose `ui` service.
---

## 📂 Project Structure

```
innovatemart-eks/
├── terraform/             # IaC for AWS infrastructure
│   ├── iam-policies/
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars
├── kubernetes/         # Kubernetes manifests for app deployment
│   ├── iam-policy.json
│   ├── ingress.yaml
│   └── retail-store-app.yaml
├── .github/workflows/     # GitHub Actions pipelines
│   └── terraform.yml
└── scripts/         
    ├── configure-developer-access.sh
    ├── deploy.sh
    └── destroy.sh
```

---

## 🛠️ Deployment Guide

### 1. Clone the Repository

```bash
git clone https://github.com/skillz008/innovatemart-project-bedrock.git
cd innovatemart-eks
```

### 2. Provision Infrastructure with Terraform

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 3. Configure kubectl Access

```bash
aws eks --region us-east-1 update-kubeconfig --name innovatemart-eks
kubectl get nodes
```

### 4. Deploy the Application

```bash
kubectl apply -f k8s-manifests/
kubectl get pods -n retail-store
```

### 5. Access the Application

* **UI Service URL:** [http://retail-store-alb-1782779718.us-east-1.elb.amazonaws.com/](http://<ALB-DNS-Name>)

---

## 👩‍💻 Developer Access Instructions

1. Use the IAM-provided credentials.
2. Update kubeconfig for read-only user:

   ```bash
   aws eks --region <region> update-kubeconfig --name innovatemart-eks --profile dev-readonly
   ```
3. Verify permissions:

   ```bash
   kubectl get pods -n retail-store
   kubectl logs <pod-name> -n retail-store
   ```

---

## 🏆 Conclusion

This project demonstrates end-to-end deployment of a production-grade Kubernetes application on AWS EKS with a focus on **IaC, CI/CD, automation, scalability, and developer experience**.
