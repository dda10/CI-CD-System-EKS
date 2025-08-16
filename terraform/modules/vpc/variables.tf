variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
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
