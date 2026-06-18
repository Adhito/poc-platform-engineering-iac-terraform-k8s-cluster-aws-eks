variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the EKS control plane and worker nodes"
  type        = list(string)
}

variable "node_group_config" {
  description = "Managed node group configuration map — output from modules/node-groups, passed directly to the community EKS module"
  type        = any
}

variable "tags" {
  description = "Tags to apply to EKS resources"
  type        = map(string)
  default     = {}
}
