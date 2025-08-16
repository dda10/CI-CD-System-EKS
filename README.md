# Homelab CI/CD Infrastructure

This Terraform configuration sets up a complete CI/CD infrastructure using:
- **Jenkins** on EKS with ALB Ingress
- **Amazon EKS** with Spot instances for cost optimization
- **AWS CodeCommit** for storing pipeline code
- **AWS Secrets Manager** for secure credential management
- **Amazon ECR** for container registry
- **AWS CodeArtifact** for artifact management

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
│                                VPC (10.0.0.0/16)                               │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                          Internet Gateway                                   ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                       │                                         │
│  ┌────────────────────────────────────┼─────────────────────────────────────────┐│
│  │            Worker Node Subnet      │         Pod IP Subnet                  ││
│  │             (11.0.0.0/24)          │        (172.25.0.0/16)                ││
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
│  │  │  │    GitLab EC2       │    │   │   │   │                                 │  ││
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

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AWS Managed Services                              │
│                                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                │
│  │   CodeCommit    │  │ Secrets Manager │  │      ECR        │                │
│  │   Repository    │  │  (Credentials)  │  │  (Container     │                │
│  │                 │  │                 │  │   Registry)     │                │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                │
│                                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                │
│  │  CodeArtifact   │  │       EFS       │  │      EBS        │                │
│  │   (Artifacts)   │  │  (File Storage) │  │ (Block Storage) │                │
│  │                 │  │                 │  │                 │                │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Traffic Flow

```
Internet → ALB Ingress → EKS Cluster
    │            │              │
    │            │              ├─ Worker Nodes (11.0.0.0/24) - Spot Instances
    │            │              │   ├─ Jenkins Pod
    │            │              │   ├─ GitLab EC2
    │            │              │   └─ EKS Worker Nodes
    │            │              │
    │            │              └─ Pod Network (172.25.0.0/16)
    │            │                  ├─ Jenkins Master Pod
    │            │                  ├─ Jenkins Agent Pods
    │            │                  ├─ Build Containers
    │            │                  └─ Application Pods
    │            │
    │            └─ ALB Ingress Routes:
    │                ├─ / → Jenkins Service
    │                ├─ /gitlab → GitLab EC2
    │                └─ /apps → EKS Services
    │
    └─ External Access:
        ├─ Developers
        ├─ CI/CD Webhooks
        └─ Monitoring Tools
```

## Data Flow

1. **Internet Traffic** → ALB → EKS Services
2. **Code Push** → CodeCommit Repository
3. **Jenkins Trigger** → Webhook from CodeCommit
4. **Pod Creation** → Jenkins creates slave pods in Pod subnet
5. **Secret Retrieval** → Pods use IRSA to access Secrets Manager
6. **Build Process** → Docker build, test, and push to ECR
7. **Artifact Storage** → Dependencies cached in CodeArtifact
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

### 1. Access Jenkins

1. Get Jenkins admin password:
   ```bash
   kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
   ```

2. Access Jenkins via port-forward:
   ```bash
   kubectl port-forward -n jenkins svc/jenkins 8080:8080
   # Then access: http://localhost:8080
   ```

3. Or wait for ALB Ingress to provision and use the external URL

### 2. Configure Jenkins

Jenkins is pre-configured with:
- Kubernetes Plugin for dynamic agent pods
- Git Plugin for repository integration
- Pipeline Plugin for CI/CD workflows
- Configuration as Code (JCasC) for automated setup

The Kubernetes cloud is automatically configured to use the EKS cluster.

### 3. Update Secrets

Update the secrets in AWS Secrets Manager:
```bash
aws secretsmanager update-secret \
  --secret-id <project-name>/<environment>/jenkins \
  --secret-string '{
    "docker_registry_user": "your-docker-user",
    "docker_registry_pass": "your-docker-password",
    "github_token": "your-github-token",
    "slack_webhook": "your-slack-webhook-url"
  }'
```

### 4. Create Your First Pipeline

1. **Clone the CodeCommit repository:**
   ```bash
   git clone <codecommit-clone-url>
   cd <repo-name>
   ```

2. **Add the sample Jenkinsfile:**
   ```bash
   cp ../sample-jenkinsfile Jenkinsfile
   git add Jenkinsfile
   git commit -m "Add sample Jenkinsfile"
   git push
   ```

3. **Create pipeline in Jenkins:**
   - New Item → Pipeline
   - Configure to use CodeCommit repository
   - Set branch and Jenkinsfile path

## Pipeline Features

The Jenkins deployment includes:

- **Kubernetes Agent Pods**: Dynamic Jenkins agents running in EKS
- **Spot Instance Workers**: Cost-optimized EKS worker nodes
- **Multi-container builds**: Docker, kubectl, and AWS CLI containers
- **Secrets Management**: Automatic retrieval from AWS Secrets Manager
- **Container Registry**: Push/pull from Amazon ECR
- **EKS Deployment**: Automated deployment to EKS cluster
- **ALB Ingress**: External access through AWS Application Load Balancer

## Security Features

- Jenkins runs as pods in EKS cluster
- EKS cluster with private worker nodes
- Spot instances for cost optimization
- IAM roles with least privilege (IRSA)
- Secrets stored in AWS Secrets Manager
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
5. Implement multi-environment deploymentsenkinsfile:**
   ```bash
   cp ../sample-jenkinsfile Jenkinsfile
   git add Jenkinsfile
   git commit -m "Add sample Jenkinsfile"
   git push
   ```

3. **Create pipeline in Jenkins:**
   - New Item → Pipeline
   - Configure to use CodeCommit repository
   - Set branch and Jenkinsfile path

## Pipeline Features

The sample pipeline includes:

- **Kubernetes Slave Pods**: Dynamic Jenkins agents running in EKS
- **Multi-container builds**: Docker, kubectl, and AWS CLI containers
- **Secrets Management**: Automatic retrieval from AWS Secrets Manager
- **Container Registry**: Push/pull from Amazon ECR
- **EKS Deployment**: Automated deployment to EKS cluster
- **Notifications**: Slack integration for build status

## Security Features

- Jenkins runs in private subnet
- EKS cluster in private subnets
- IAM roles with least privilege
- Secrets stored in AWS Secrets Manager
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

### Jenkins can't connect to EKS
1. Check IAM permissions for Jenkins role
2. Verify EKS cluster is accessible from Jenkins subnet
3. Check security group rules

### Pipeline fails to pull from CodeCommit
1. Verify IAM permissions for CodeCommit
2. Check Git configuration on Jenkins
3. Ensure CodeCommit plugin is installed

### Secrets not accessible
1. Check IAM permissions for Secrets Manager
2. Verify secret exists and has correct name
3. Check secret format (must be valid JSON)

## Cost Optimization

- Use Spot instances for EKS node groups
- Configure auto-scaling for EKS nodes
- Use smaller instance types for development
- Enable EBS GP3 volumes for better cost/performance

## Next Steps

1. Set up monitoring with Prometheus/Grafana
2. Implement GitOps with ArgoCD
3. Add security scanning with Trivy
4. Configure backup strategies
5. Implement multi-environment deployments
