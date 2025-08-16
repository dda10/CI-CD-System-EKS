resource "helm_release" "gitlab" {
  name             = "gitlab"
  repository       = "https://charts.gitlab.io/"
  chart            = "gitlab"
  namespace        = "gitlab"
  version          = "8.5.2"
  create_namespace = true

  set {
    name  = "global.hosts.domain"
    value = var.domain
  }

  set {
    name  = "global.hosts.externalIP"
    value = var.external_ip
  }

  set {
    name  = "certmanager-issuer.email"
    value = "admin@${var.domain}"
  }

  set {
    name  = "certmanager.install"
    value = "false"
  }

  set {
    name  = "global.ingress.configureCertmanager"
    value = "false"
  }

  set {
    name  = "global.ingress.tls.enabled"
    value = "false"
  }

  set {
    name  = "nginx-ingress.enabled"
    value = "false"
  }

  set {
    name  = "global.ingress.class"
    value = "alb"
  }

  set {
    name  = "global.ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }

  set {
    name  = "global.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "global.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "postgresql.persistence.size"
    value = "8Gi"
  }

  set {
    name  = "redis.master.persistence.size"
    value = "5Gi"
  }

  set {
    name  = "minio.persistence.size"
    value = "10Gi"
  }

  set {
    name  = "gitlab.gitaly.persistence.size"
    value = "50Gi"
  }

  timeout = 600
}


