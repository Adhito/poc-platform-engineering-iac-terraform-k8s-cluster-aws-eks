locals {
  # EKS-required tags for subnet discovery by the AWS Load Balancer Controller
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  # Single NAT Gateway across all AZs (cost optimisation for learning)
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  # Internet Gateway for public subnets
  create_igw = true

  # DNS — both required by EKS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Public subnets auto-assign a public IPv4 address
  map_public_ip_on_launch = true

  # Do not manage the default NACL — avoids a schema conflict between
  # VPC module v5.x and the current AWS provider version.
  manage_default_network_acl = false

  # EKS subnet tags
  public_subnet_tags  = local.public_subnet_tags
  private_subnet_tags = local.private_subnet_tags

  tags = var.tags
}
