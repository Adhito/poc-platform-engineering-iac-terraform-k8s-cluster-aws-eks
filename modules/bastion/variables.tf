variable "cluster_name" {
  description = "EKS cluster name — used to name bastion resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the bastion will be placed"
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID for the bastion (NAT gateway provides outbound for SSM)"
  type        = string
}

variable "aws_region" {
  description = "AWS region — written to /etc/profile.d/eks.sh on the bastion"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "tags" {
  description = "Tags applied to all bastion resources"
  type        = map(string)
  default     = {}
}
