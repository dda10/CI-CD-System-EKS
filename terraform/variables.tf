variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "node_instance_type" {
  description = "EKS node instance type"
  type        = string
}

variable "worker_subnet_cidrs" {
  description = "CIDR blocks for worker node subnets"
  type        = list(string)
}

variable "pod_subnet_cidrs" {
  description = "CIDR blocks for pod IP subnets"
  type        = list(string)
}

variable "subnet_count" {
  description = "Number of subnets to create"
  type        = number
  default     = 2
}


