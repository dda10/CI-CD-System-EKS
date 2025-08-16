module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${var.project_name}-${var.environment}"
  kubernetes_version = "1.31"

  vpc_id                                   = var.vpc_id
  subnet_ids                               = var.worker_subnet_ids
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_irsa                              = true

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_POD_ENI               = "true"
          AWS_VPC_K8S_CNI_EXTERNALSNAT = "true"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent    = true
      before_compute = true
    }
    aws-efs-csi-driver = {
      most_recent    = true
      before_compute = true
    }

  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    main = {
      name = "${var.project_name}-ng"

      instance_types = [var.node_instance_type]
      capacity_type  = "SPOT"

      min_size     = 1
      max_size     = 4
      desired_size = 2

    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}











