variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "worker_subnet_ids" {
  description = "Worker node subnet IDs"
  type        = list(string)
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "node_instance_type" {
  description = "EKS node instance type"
  type        = string
}
