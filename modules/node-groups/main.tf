# ---------------------------------------------------------------------------
# Node IAM Role
# Trust: ec2.amazonaws.com — worker nodes are EC2 instances
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "node_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# ---------------------------------------------------------------------------
# Managed Node Group Configuration Map
# Assembled here and exported as output; consumed by modules/eks which passes
# it directly to the terraform-aws-modules/eks community module.
# ---------------------------------------------------------------------------

locals {
  managed_node_groups = {
    "${var.environment}-ng" = {
      name             = "${var.cluster_name}-${var.environment}-ng"
      instance_types   = [var.instance_type]
      subnet_ids       = var.subnet_ids
      create_iam_role  = false
      iam_role_arn     = aws_iam_role.node.arn

      min_size     = var.min_size
      desired_size = var.desired_size
      max_size     = var.max_size

      labels = {
        role        = "eks-node"
        environment = var.environment
      }

      tags = var.tags
    }
  }
}
