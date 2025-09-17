terraform {
  backend "s3" {
    bucket = "ise-lab-sandbox-tfstate"
    key    = "terraform.tfstate"
    region = "ap-southeast-1"
  }

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


  }
}

provider "aws" {
  region = var.aws_region
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
  pod_cidr             = var.pod_cidr
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  project_name       = var.project_name
  environment        = var.environment
  node_instance_type = var.node_instance_type

}

# Bastion Host Module
module "bastion_host" {
  source = "./modules/bastion_host"

  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]
  project_name     = var.project_name
  environment      = var.environment
  aws_region       = var.aws_region
  cluster_name     = "${var.project_name}-${var.environment}"
}

# Jenkins Module
module "jenkins" {
  source = "./modules/jenkins"

  project_name      = var.project_name
  environment       = var.environment
  oidc_provider_arn = "arn:aws:iam::712375977057:oidc-provider/oidc.eks.ap-southeast-1.amazonaws.com/id/F8CAFF7FF2AB34538DADCA0D25407685"
  oidc_issuer_url   = "oidc.eks.ap-southeast-1.amazonaws.com/id/F8CAFF7FF2AB34538DADCA0D25407685"
}



module "karpenter" {
  source = "./modules/karpenter"

  project_name      = var.project_name
  environment       = var.environment
  oidc_provider_arn = "arn:aws:iam::712375977057:oidc-provider/oidc.eks.ap-southeast-1.amazonaws.com/id/F8CAFF7FF2AB34538DADCA0D25407685"
  oidc_issuer_url   = "oidc.eks.ap-southeast-1.amazonaws.com/id/F8CAFF7FF2AB34538DADCA0D25407685"
}



