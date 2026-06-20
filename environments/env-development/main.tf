# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.10.0/23", "10.0.12.0/23"]
  availability_zones   = var.availability_zones
  cluster_name         = var.cluster_name
}

# ---------------------------------------------------------------------------
# Node Groups
# Creates the node IAM role and assembles the managed_node_groups config map.
# Must run before modules/eks so the role ARN is available.
# ---------------------------------------------------------------------------

module "node_groups" {
  source = "../../modules/node-groups"

  cluster_name  = var.cluster_name
  environment   = var.environment
  instance_type = var.node_instance_type
  min_size      = var.node_min_size
  desired_size  = var.node_desired_size
  max_size      = var.node_max_size
  subnet_ids    = module.vpc.private_subnet_ids
}

# ---------------------------------------------------------------------------
# EKS Cluster
# Receives the fully-formed node group config map (including the role ARN)
# from modules/node-groups — no circular dependency.
# ---------------------------------------------------------------------------

module "eks" {
  source = "../../modules/eks"

  cluster_name      = var.cluster_name
  cluster_version   = var.cluster_version
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  node_group_config = module.node_groups.node_group_config
}

# ---------------------------------------------------------------------------
# Scheduler
# Scales the EKS node group ASGs on/off via EventBridge + Lambda.
# Runs after modules/eks so the ASG names are known.
# ---------------------------------------------------------------------------

module "scheduler" {
  source = "../../modules/scheduler"

  cluster_name         = var.cluster_name
  node_group_asg_names = module.eks.node_group_asg_names
  region               = var.aws_region
  start_min_size       = var.node_min_size
  start_desired_size   = var.node_desired_size
  start_max_size       = var.node_max_size
  enabled              = var.scheduler_enabled
}

# ---------------------------------------------------------------------------
# Bastion Host
# SSM-only access — no key pair, no public IP, no inbound security group rules.
# Access patterns:
#   Interactive : bash scripts/connect-bastion-dev.sh
#   Port-forward: bash scripts/tunnel-dev.sh (kubectl runs locally on localhost:6443)
# ---------------------------------------------------------------------------

module "bastion" {
  source = "../../modules/bastion"

  cluster_name  = var.cluster_name
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.private_subnet_ids[0]
  aws_region    = var.aws_region
  instance_type = var.bastion_instance_type

  # Wait for EKS to be fully ready before provisioning the bastion.
  # user_data calls `aws eks update-kubeconfig` at boot — the EKS endpoint must
  # exist before that command runs or the kubeconfig will never be written.
  depends_on = [module.eks]
}

# ---------------------------------------------------------------------------
# Allow the bastion to reach the EKS private API endpoint on port 443.
# The cluster security group only allows inbound from node groups by default.
# ---------------------------------------------------------------------------

resource "aws_security_group_rule" "bastion_to_eks_api" {
  description              = "Allow bastion SSM session to reach EKS private API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = module.bastion.security_group_id
}

# ---------------------------------------------------------------------------
# Grant the bastion IAM role cluster-admin access to EKS via Access Entries.
# This replaces the ad-hoc aws eks create-access-entry / associate-access-policy
# commands that were previously run manually.
# ---------------------------------------------------------------------------

resource "aws_eks_access_entry" "bastion" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.bastion.iam_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.bastion.iam_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}

# ---------------------------------------------------------------------------
# Data source for the kubernetes provider (uncomment provider block in
# versions.tf when you want to manage k8s resources from Terraform)
# ---------------------------------------------------------------------------

# data "aws_eks_cluster" "current" {
#   name       = module.eks.cluster_name
#   depends_on = [module.eks]
# }
