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
  # enable_irsa                              = false
  enable_irsa = true

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
          ENABLE_POD_ENI = "true"
          AWS_VPC_K8S_CNI_EXTERNALSNAT = "true"
        }
      })
    }
    aws-ebs-csi-driver = {
     most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        controller = {
          serviceAccount = {
            annotations = {
              "eks.amazonaws.com/role-arn" = aws_iam_role.ebs_csi_driver.arn
            }
          }
        }
      }) 
    }
    aws-efs-csi-driver = {
      most_recent              = true
      before_compute           = true
      configuration_values = jsonencode({
        controller = {
          serviceAccount = {
            annotations = {
              "eks.amazonaws.com/role-arn" = aws_iam_role.efs_csi_driver.arn
            }
          }
        }
      })
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

# Cert-manager
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  version          = "v1.18.2"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [module.eks]
}

# AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.0"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller.arn
  }

  set {
    name  = "region"
    value = data.aws_region.current.id
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [helm_release.cert_manager]
}

# IAM Role for AWS Load Balancer Controller
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.project_name}-${var.environment}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "${module.eks.cluster_oidc_issuer_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  role       = aws_iam_role.aws_load_balancer_controller.name
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_ec2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  role       = aws_iam_role.aws_load_balancer_controller.name
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# EBS CSI Driver IAM Role
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.project_name}-${var.environment}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
          "${module.eks.cluster_oidc_issuer_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}

#EFS CSI Driver IAM Role

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

resource "aws_iam_role_policy" "ebs_csi_driver_additional" {
  name = "${var.project_name}-${var.environment}-ebs-csi-additional"
  role = aws_iam_role.ebs_csi_driver.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeRegions",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "efs_csi_driver" {
  name = "${var.project_name}-${var.environment}-efs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
          "${module.eks.cluster_oidc_issuer_url}:sub" = "system:serviceaccount:kube-system:efs-csi-controller-sa"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi_driver.name
}

resource "aws_iam_role_policy" "efs_csi_driver_additional" {
  name = "${var.project_name}-${var.environment}-efs-csi-additional"
  role = aws_iam_role.efs_csi_driver.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets"
        ]
        Resource = "*"
      }
    ]
  })
}

# Default StorageClass for EBS
resource "kubernetes_storage_class" "ebs_gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = "Delete"
  volume_binding_mode   = "WaitForFirstConsumer"
  allow_volume_expansion = true
  
  parameters = {
    type = "gp3"
    encrypted = "true"
  }

  depends_on = [module.eks]
}



