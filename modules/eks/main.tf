# ---------------------------------------------------------------------------
# Cluster IAM Role
# Trust: eks.amazonaws.com — allows the EKS service to manage resources
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "eks_cluster_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# ---------------------------------------------------------------------------
# EKS Cluster (via community module)
# terraform-aws-modules/eks/aws v20.x accepts managed_node_groups inline
# ---------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  create_iam_role = false
  iam_role_arn    = aws_iam_role.eks_cluster.arn

  # Disable KMS envelope encryption — not needed for a POC and avoids
  # the kms:TagResource permission requirement and $1/month key cost.
  create_kms_key            = false
  cluster_encryption_config = {}

  # Private-only endpoint — access via SSM bastion (connect-bastion-dev.sh)
  # or SSM port-forward tunnel (tunnel-dev.sh). No public exposure.
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  # Automatically grant the Terraform IAM caller cluster-admin access via EKS Access Entry.
  # v20.x defaults this to false — without it, the user who ran terraform apply cannot
  # authenticate to the cluster via kubectl.
  enable_cluster_creator_admin_permissions = true

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Managed node groups — config map comes from modules/node-groups
  eks_managed_node_groups = var.node_group_config

  tags = var.tags
}

# ---------------------------------------------------------------------------
# OIDC Provider — managed internally by terraform-aws-modules/eks/aws v20.x
# (enable_irsa = true by default). Use module.eks.oidc_provider_arn in outputs.
# ---------------------------------------------------------------------------
# Managed Add-ons
# vpc-cni : AWS VPC CNI plugin (default CNI)
# kube-proxy : Kubernetes network proxy
# coredns   : Cluster DNS
# ---------------------------------------------------------------------------

resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                     = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                     = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                     = var.tags
}
