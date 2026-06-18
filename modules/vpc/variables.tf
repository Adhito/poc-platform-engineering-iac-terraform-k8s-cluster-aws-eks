variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ, used for LBs and NAT Gateway)"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (one per AZ, used for EKS worker nodes)"
  type        = list(string)
  default     = ["10.0.10.0/23", "10.0.12.0/23"]
}

variable "availability_zones" {
  description = "List of AWS Availability Zones to deploy into (minimum 2)"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name — used to generate the required kubernetes.io/cluster/<name> subnet tags"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all VPC resources"
  type        = map(string)
  default     = {}
}
