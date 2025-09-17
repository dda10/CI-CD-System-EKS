# LAB CI/CD Infrastructure

This Terraform configuration sets up a complete CI/CD infrastructure using:

- **Jenkins** on EKS with ALB Ingress
- **GitLab** on EKS with ALB Ingress
- **Amazon EKS** with Spot instances for cost optimization

## Architecture

```
                                    Internet
                                       │
                                       ▼
                          ┌─────────────────────────┐
                          │  Application Load       │
                          │     Balancer            │
                          │   (Public Access)       │
                          └─────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                VPC (10.35.120.0/22)                            │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                          Internet Gateway                                   ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                       │                                         │
│  ┌────────────────────────────────────┼─────────────────────────────────────────┐│
│  │            Worker Node Subnet      │         Pod IP Subnet                  ││
│  │          (10.35.122.0/24)          │        (100.64.0.0/16)                ││
│  │                                    │                                        ││
│  │  ┌─────────────────────────────────┐   │   ┌─────────────────────────────────┐  ││
│  │  │       EKS Cluster           │   │   │      Jenkins Slave Pods        │  ││
│  │  │                             │   │   │                                 │  ││
│  │  │  ┌─────────────────────────┐    │   │   │  ┌─────────────────────────┐    │  ││
│  │  │  │   Worker Nodes      │    │   │   │  │    Build Containers     │    │  ││
│  │  │  │   - t3.medium       │    │   │   │  │    - Docker             │    │  ││
│  │  │  │   - Auto Scaling    │    │   │   │  │    - kubectl            │    │  ││
│  │  │  │   - IRSA Enabled    │    │   │   │  │    - AWS CLI            │    │  ││
│  │  │  └─────────────────────────┘    │   │   │  └─────────────────────────┘    │  ││
│  │  │                             │   │   │                                 │  ││
│  │  │  ┌─────────────────────────┐    │   │   │  ┌─────────────────────────┐    │  ││
│  │  │  │    Jenkins Pod      │    │───┼───┼───┼──│     Dynamic Pods        │    │  ││
│  │  │  │    - Master Node    │    │   │   │   │  │   - On-demand           │    │  ││
│  │  │  │    - Pipeline Mgmt  │    │   │   │   │  │   - Auto-cleanup        │    │  ││
│  │  │  └─────────────────────────┘    │   │   │  └─────────────────────────┘    │  ││
│  │  │                             │   │   │                                 │  ││
│  │  │  ┌─────────────────────────┐    │   │   │                                 │  ││
│  │  │  │    GitLab Pod       │    │   │   │   │                                 │  ││
│  │  │  │    - Git Repository │    │   │   │   │                                 │  ││
│  │  │  │    - CI/CD Runner   │    │   │   │   │                                 │  ││
│  │  │  └─────────────────────────┘    │   │   │                                 │  ││
│  │  └─────────────────────────────────┘   │   └─────────────────────────────────┘  ││
│  └────────────────────────────────────┼─────────────────────────────────────────┘│
│                                       │                                         │
│  ┌────────────────────────────────────┼─────────────────────────────────────────┐│
│  │                    EKS Add-ons     │                                        ││
│  │  • VPC CNI (Pod Networking)        │                                        ││
│  │  • CoreDNS (Service Discovery)     │                                        ││
│  │  • EBS CSI (Block Storage)         │                                        ││
│  │  • EFS CSI (Shared Storage)        │                                        ││
│  │  • IRSA (Service Account Roles)    │                                        ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│                              AWS Managed Services                             │
│                                                                               │
│                                                                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                │
│  │  CodeArtifact   │  │       EFS       │  │      EBS        │                │
│  │   (Artifacts)   │  │  (File Storage) │  │ (Block Storage) │                │
│  │                 │  │                 │  │                 │                │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                │
└───────────────────────────────────────────────────────────────────────────────┘
```

## Traffic Flow

```
Internet → ALB Ingress → EKS Cluster
    │            │              │
    │            │              ├─ Worker Nodes (10.35.122.0/24) - Spot Instances
    │            │              │   ├─ Jenkins Pod
    │            │              │   ├─ GitLab Pod
    │            │              │   └─ EKS Worker Nodes
    │            │              │
    │            │              └─ Pod Network (100.64.0.0/16)
    │            │                  ├─ Jenkins Master Pod
    │            │                  ├─ Jenkins Agent Pods
    │            │                  ├─ Build Containers
    │            │                  └─ Application Pods
    │            │
    │            └─ ALB Ingress Routes:
    │                ├─ /jenkins → Jenkins Service
    │                ├─ /gitlab → GitLab Service
    │                └─ /apps → EKS Services
    │
    └─ External Access:
        ├─ Developers
        ├─ CI/CD Webhooks
        └─ Monitoring Tools
```

## Data Flow

1. **Internet Traffic** → ALB → EKS Services
2. **Code Push** → GitLab Repository
3. **Jenkins Trigger** → Webhook from GitLab
4. **Pod Creation** → Jenkins creates slave pods in Pod subnet
5. **Secret Retrieval** → Pods use Vault
6. **Build Process** → Docker build, test, and push to ECR
7. **Artifact Storage** → Dependencies cached in Gitlab
8. **Deployment** → Kubernetes manifests applied to EKS
9. **Storage** → EBS for persistent volumes, EFS for shared storage

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0 installed
3. kubectl installed (for EKS management)

## Deployment

1. **Initialize Terraform:**

   ```bash
   cd terraform
   terraform init
   ```

2. **Review and modify variables:**

   ```bash
   # Edit terraform.tfvars with your values
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Deploy infrastructure:**

   ```bash
   terraform plan
   terraform apply
   ```

4. **Get outputs:**
   ```bash
   terraform output
   ```

## Post-Deployment Setup

### 1. Access Services

**Access Jenkins:**

1. Get Jenkins admin password:
   ```bash
   kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
   ```
2. Access via ALB: `https://<alb-dns>/jenkins`

**Access GitLab:**

1. Get GitLab root password:
   ```bash
   kubectl get secret -n gitlab gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 --decode
   ```
2. Access via ALB: `https://<alb-dns>/gitlab`

### 2. Configure Jenkins

Jenkins is pre-configured with:

- Kubernetes Plugin for dynamic agent pods
- Git Plugin for repository integration
- Pipeline Plugin for CI/CD workflows
- Configuration as Code (JCasC) for automated setup

The Kubernetes cloud is automatically configured to use the EKS cluster.

### 3. Update Secrets

Update the secrets in Vault:

### 4. Create Your First Pipeline

1. **Create project in GitLab:**

   - Access GitLab via ALB
   - Create new project
   - Add Jenkinsfile to repository

2. **Configure Jenkins pipeline:**

   - New Item → Pipeline
   - Configure to use GitLab repository
   - Set webhook for automatic triggers

3. **Set up GitLab webhook:**
   - Project Settings → Webhooks
   - Add Jenkins webhook URL
   - Configure push events

## Pipeline Features

The Jenkins deployment includes:

- **Kubernetes Agent Pods**: Dynamic Jenkins agents running in EKS
- **Spot Instance Workers**: Cost-optimized EKS worker nodes
- **Multi-container builds**: Docker, kubectl, and AWS CLI containers
- **Secrets Management**: Automatic retrieval from Vault
- **Container Registry**: Push/pull from Amazon ECR
- **EKS Deployment**: Automated deployment to EKS cluster
- **ALB Ingress**: External access through AWS Application Load Balancer

## Security Features

- Jenkins runs as pods in EKS cluster
- EKS cluster with private worker nodes
- Spot instances for cost optimization
- IAM roles with least privilege (IRSA)
- Secrets stored in Vault
- VPC security groups for network isolation

## Monitoring and Logging

- CloudWatch logs for EKS cluster
- Jenkins build logs
- ALB access logs
- VPC Flow Logs (optional)

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

## Troubleshooting

### Jenkins pod not starting

1. Check pod status: `kubectl get pods -n jenkins`
2. Check pod logs: `kubectl logs -n jenkins <pod-name>`
3. Verify persistent volume: `kubectl get pv,pvc -n jenkins`

### Pipeline fails to connect to EKS

1. Verify IRSA permissions for Jenkins service account
2. Check EKS cluster is accessible from Jenkins pod
3. Ensure Kubernetes plugin is properly configured

### ALB Ingress not working

1. Verify AWS Load Balancer Controller is installed
2. Check Ingress status: `kubectl get ingress -n jenkins`
3. Ensure security groups allow traffic

## Cost Optimization

- Uses Spot instances for EKS node groups (up to 90% cost savings)
- Configure auto-scaling for EKS nodes
- Use smaller instance types for development
- Enable EBS GP3 volumes for better cost/performance
- Jenkins agents are created on-demand and auto-cleanup

## Next Steps

1. Set up monitoring with Prometheus/Grafana
2. Implement GitOps with ArgoCD
3. Add security scanning with Trivy
4. Configure backup strategies for persistent volumes

## Pipeline Features

The sample pipeline includes:

- **Kubernetes Slave Pods**: Dynamic Jenkins agents running in EKS
- **Multi-container builds**: Docker, kubectl, and AWS CLI containers
- **Secrets Management**: Automatic retrieval from Vault
- **Container Registry**: Push/pull from Gitlab
- **EKS Deployment**: Automated deployment to EKS cluster
- **Notifications**: Slack integration for build status

## Security Features

- Jenkins runs in private subnet
- EKS cluster in private subnets
- IAM roles with least privilege
- Secrets stored in Vault
- VPC security groups for network isolation

## Monitoring and Logging

- CloudWatch logs for EKS cluster
- Jenkins build logs
- ALB access logs

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
``
```

