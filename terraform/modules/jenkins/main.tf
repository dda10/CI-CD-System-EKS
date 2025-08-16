resource "helm_release" "jenkins" {
  name             = "jenkins"
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  namespace        = "jenkins"
  create_namespace = true

  set {
    name  = "controller.serviceType"
    value = "ClusterIP"
  }

  set {
    name  = "controller.ingress.enabled"
    value = "true"
  }

  set {
    name  = "controller.ingress.ingressClassName"
    value = "alb"
  }

  set {
    name  = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.size"
    value = "20Gi"
  }
  
  set {
    name  = "persistence.storageClass"
    value = "gp3"
  }

  depends_on = [var.load_balancer_controller_ready]
}

# Jenkins IAM Role for IRSA
resource "aws_iam_role" "jenkins" {
  name = "${var.project_name}-${var.environment}-jenkins"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_issuer_url}:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "${var.oidc_issuer_url}:sub" = "system:serviceaccount:jenkins:jenkins"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "jenkins" {
  name = "${var.project_name}-${var.environment}-jenkins-policy"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      },
    ]
  })
}

