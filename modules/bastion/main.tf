# ---------------------------------------------------------------------------
# Bastion Host — SSM-only access, no key pair, no inbound firewall rules.
# SSM agent reaches AWS endpoints via the VPC NAT gateway (outbound HTTPS).
# Supports two access patterns:
#   Method 1 — Interactive shell : scripts/connect-bastion-dev.sh
#   Method 2 — Port-forward tunnel: scripts/tunnel-dev.sh (kubectl runs locally)
# ---------------------------------------------------------------------------

# Latest Amazon Linux 2 AMI — SSM agent pre-installed
data "aws_ssm_parameter" "al2_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

# ---------------------------------------------------------------------------
# IAM Role — allows EC2 instance to register with SSM
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "bastion_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "${var.cluster_name}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.bastion_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow the bastion to run `aws eks update-kubeconfig` from inside the SSM shell
resource "aws_iam_role_policy" "eks_read" {
  name = "${var.cluster_name}-bastion-eks-read"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "EKSDescribe"
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.cluster_name}-bastion-profile"
  role = aws_iam_role.bastion.name
  tags = var.tags
}

# ---------------------------------------------------------------------------
# Security Group — egress-only (SSM uses outbound HTTPS, no inbound needed)
# ---------------------------------------------------------------------------

resource "aws_security_group" "bastion" {
  name        = "${var.cluster_name}-bastion-sg"
  description = "SSM bastion - egress only, no inbound rules"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound (SSM + kubectl to EKS private endpoint)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# EC2 Instance
# ---------------------------------------------------------------------------

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  user_data_replace_on_change = true

  # No key pair — access only via SSM Session Manager
  # No public IP — traffic routes through NAT gateway

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Install AWS CLI v2 (Amazon Linux 2 ships with v1 — v2 outputs v1beta1 tokens)
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp/
    /tmp/aws/install --update
    rm -rf /tmp/awscliv2.zip /tmp/aws

    # Install kubectl (latest stable)
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -Lo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl

    # Environment variables — sourced by /etc/bashrc for SSM interactive sessions
    cat >> /etc/bashrc <<'ENVEOF'
export AWS_DEFAULT_REGION="${var.aws_region}"
export CLUSTER_NAME="${var.cluster_name}"
ENVEOF

    # Pre-configure kubectl for ssm-user (default location, no KUBECONFIG var needed).
    # user_data runs as root; ssm-user does not exist yet at boot time so chown
    # silently fails. Setting 777 on the directory lets ssm-user create/update
    # the kubeconfig later (e.g. after a cluster recreate) without sudo.
    mkdir -p /home/ssm-user/.kube
    chmod 777 /home/ssm-user/.kube
    /usr/local/bin/aws eks update-kubeconfig \
      --name "${var.cluster_name}" \
      --region "${var.aws_region}" \
      --kubeconfig /home/ssm-user/.kube/config
    chown -R ssm-user:ssm-user /home/ssm-user/.kube 2>/dev/null || true
    chmod 666 /home/ssm-user/.kube/config
  EOF

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-bastion"
  })
}
