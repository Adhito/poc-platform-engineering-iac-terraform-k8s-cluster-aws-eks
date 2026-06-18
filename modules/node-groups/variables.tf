variable "cluster_name" {
  description = "EKS cluster name — used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment label applied to node group name and Kubernetes labels"
  type        = string
  default     = "development"
}

variable "instance_type" {
  description = "EC2 instance type for the worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "min_size" {
  description = "Minimum number of nodes in the managed node group"
  type        = number
  default     = 2
}

variable "desired_size" {
  description = "Desired number of nodes in the managed node group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of nodes in the managed node group"
  type        = number
  default     = 5
}

variable "subnet_ids" {
  description = "Private subnet IDs where the worker nodes will be placed"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to node group resources"
  type        = map(string)
  default     = {}
}
