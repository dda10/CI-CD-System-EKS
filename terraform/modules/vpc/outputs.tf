output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

# For EKS worker nodes (private subnets)
output "worker_subnet_ids" {
  value = module.vpc.private_subnets
}

