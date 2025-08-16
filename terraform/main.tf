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
