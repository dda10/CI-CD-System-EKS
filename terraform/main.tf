terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, var.subnet_count)
  project_name         = var.project_name
  environment          = var.environment
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  vpc_id             = module.vpc.vpc_id
  worker_subnet_ids  = module.vpc.worker_subnet_ids
  project_name       = var.project_name
  environment        = var.environment
  node_instance_type = var.node_instance_type
}

# Jenkins Module
module "jenkins" {
  source = "./modules/jenkins"

  project_name      = var.project_name
  environment       = var.environment
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url
  load_balancer_controller_ready = module.eks.load_balancer_controller_ready

}

# GitLab Module
module "gitlab" {
  source = "./modules/gitlab"

  domain       = "${var.project_name}.local"
  external_ip  = ""
  project_name = var.project_name
  environment  = var.environment
}

# Bastion Host Module
module "bastion_host" {
  source = "./modules/bastion_host"

  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]
  project_name     = var.project_name
  environment      = var.environment
  aws_region       = var.aws_region
  cluster_name = "${var.project_name}-${var.environment}"
}


