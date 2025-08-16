output "vpc_id" {
  value = module.vpc.vpc_id
}

output "worker_subnet_ids" {
  value = module.vpc.public_subnets
}

output "pod_subnet_ids" {
  value = module.vpc.private_subnets
}

# Legacy outputs for compatibility
output "public_subnet_ids" {
  value = [module.vpc.public_subnets[0]]
}

output "private_subnet_ids" {
  value = [module.vpc.public_subnets[0]]
}
