module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr
  azs  = var.availability_zones

  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs
  
  map_public_ip_on_launch = true

  enable_nat_gateway   = false
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                                       = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "owned"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                             = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "owned"
  }

  tags = {
    Terraform   = "true"
    Environment = var.environment
    Project     = var.project_name
  }
}
