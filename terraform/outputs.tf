output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "worker_subnet_cidrs" {
  description = "Worker node subnet CIDRs (primary CIDR)"
  value       = var.private_subnet_cidrs
}

output "pod_subnet_cidrs" {
  description = "Pod subnet CIDRs (secondary CIDR)"
  value       = var.pod_cidr
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "bastion_instance_id" {
  description = "Bastion host instance ID"
  value       = module.bastion_host.bastion_instance_id
}

