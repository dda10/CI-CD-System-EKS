data "aws_caller_identity" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${var.project_name}-${var.environment}"
  kubernetes_version = "1.32"

  vpc_id                                   = var.vpc_id
  subnet_ids                               = var.public_subnet_ids
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_irsa                              = false

  access_entries = {
    bastion = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-bastion-role"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
        }
      })
    }
    aws-ebs-csi-driver = {
      addon_version            = "v1.40.0-eksbuild.1"
      service_account_role_arn = aws_iam_role.ebs_csi.arn
    }
    aws-efs-csi-driver = {
      addon_version            = "v2.1.4-eksbuild.1"
      service_account_role_arn = aws_iam_role.efs_csi.arn
    }

  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    main = {
      name = "${var.project_name}-ng"

      instance_types = [var.node_instance_type, "t3.small", "t3.large"]
      capacity_type  = "SPOT"

      min_size     = 1
      max_size     = 5
      desired_size = 1
      
      scaling_config = {
        desired_size = 1
        max_size     = 5
        min_size     = 1
      }

      update_config = {
        max_unavailable_percentage = 50
      }
      
      force_update_version = true

      vpc_security_group_ids = [aws_security_group.node_group_additional.id]

      # Set IMDS hop count to 2 for pods to access metadata
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }

      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        yum install -y awscli
      EOT


    }
  }

  node_security_group_additional_rules = {
    ingress_alb_http = {
      description              = "ALB to node groups"
      protocol                 = "tcp"
      from_port                = 8080
      to_port                  = 8080
      type                     = "ingress"
      source_security_group_id = aws_security_group.alb.id
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# Additional security group for node groups
resource "aws_security_group" "node_group_additional" {
  name_prefix = "${var.project_name}-${var.environment}-node-additional"
  vpc_id      = var.vpc_id

  ingress {
    description     = "ALB to nodes"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "ALB to NodePort range"
    from_port       = 30000
    to_port         = 32767
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-node-additional"
  }
}

# EBS CSI Driver IAM Role for IRSA
resource "aws_iam_role" "ebs_csi" {
  name = "${var.project_name}-${var.environment}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.ap-southeast-1.amazonaws.com/id/F8CAFF7FF2AB34538DADCA0D25407685"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "oidc.eks.ap-southeast-1.amazonaws.com/id/F8CAFF7FF2AB34538DADCA0D25407685:aud" = "sts.amazonaws.com"
          "oidc.eks.ap-southeast-1.amazonaws.com/id/F8CAFF7FF2AB34538DADCA0D25407685:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}

resource "aws_iam_role_policy" "ebs_csi_additional" {
  name = "${var.project_name}-${var.environment}-ebs-csi-additional"
  role = aws_iam_role.ebs_csi.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications",
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:DeleteSnapshot",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# EFS CSI Driver IAM Role
resource "aws_iam_role" "efs_csi" {
  name = "${var.project_name}-${var.environment}-efs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.ap-southeast-1.amazonaws.com/id/F8CAFF7FF2AB34538DADCA0D25407685"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "oidc.eks.ap-southeast-1.amazonaws.com/id/F8CAFF7FF2AB34538DADCA0D25407685:aud" = "sts.amazonaws.com"
          "oidc.eks.ap-southeast-1.amazonaws.com/id/F8CAFF7FF2AB34538DADCA0D25407685:sub" = "system:serviceaccount:kube-system:efs-csi-controller-sa"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi.name
}

# AWS Load Balancer Controller IAM Role
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.project_name}-${var.environment}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.ap-southeast-1.amazonaws.com/id/F8CAFF7FF2AB34538DADCA0D25407685"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "oidc.eks.ap-southeast-1.amazonaws.com/id/F8CAFF7FF2AB34538DADCA0D25407685:aud" = "sts.amazonaws.com"
          "oidc.eks.ap-southeast-1.amazonaws.com/id/F8CAFF7FF2AB34538DADCA0D25407685:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  role       = aws_iam_role.aws_load_balancer_controller.name
}


resource "aws_iam_role_policy" "aws_load_balancer_controller" {
  name   = "${var.project_name}-${var.environment}-aws-load-balancer-controller"
  role   = aws_iam_role.aws_load_balancer_controller.id
  policy = file("${path.module}/alb-policy.json")
}





