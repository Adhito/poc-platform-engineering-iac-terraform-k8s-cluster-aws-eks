variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-3"
}

variable "environment" {
  description = "Environment label used in default_tags"
  type        = string
  default     = "development"
}

# ---------------------------------------------------------------------------
# EKS Cluster
# ---------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster (no default — must be set in terraform.tfvars)"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.34"
}

# ---------------------------------------------------------------------------
# VPC / Networking
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to use (minimum 2 for HA)"
  type        = list(string)
  default     = ["ap-southeast-3a", "ap-southeast-3b"]
}

# ---------------------------------------------------------------------------
# Worker Nodes
# ---------------------------------------------------------------------------

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_min_size" {
  description = "Minimum nodes in the managed node group"
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Desired nodes in the managed node group"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum nodes in the managed node group"
  type        = number
  default     = 5
}

# ---------------------------------------------------------------------------
# Bastion
# ---------------------------------------------------------------------------

variable "bastion_instance_type" {
  description = "EC2 instance type for the SSM bastion host"
  type        = string
  default     = "t3.micro"
}

# ---------------------------------------------------------------------------
# Scheduler
# ---------------------------------------------------------------------------

variable "scheduler_enabled" {
  description = "Set to false to disable the weekend start/stop scheduler"
  type        = bool
  default     = true
}
