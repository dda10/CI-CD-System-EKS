variable "domain" {
  description = "Domain for GitLab"
  type        = string
  default     = "gitlab.local"
}

variable "external_ip" {
  description = "External IP for GitLab"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}
