#!/bin/bash
# ---------------------------------------------------------------------------
# connect-bastion-dev.sh  —  Method 1: Interactive SSM shell on the bastion
#
# The bastion lives inside the VPC and can reach the EKS private endpoint.
# kubectl and kubeconfig are pre-configured at boot — just run kubectl immediately.
#
# No manual setup needed. user_data handles:
#   - AWS CLI v2 install
#   - kubectl install
#   - kubeconfig at /home/ssm-user/.kube/config
#   - AWS_DEFAULT_REGION + CLUSTER_NAME exported via /etc/bashrc
# ---------------------------------------------------------------------------
set -e

# AWS CLI named profile. Override before running if your profile name differs:
#   AWS_PROFILE=my-profile bash scripts/connect-bastion-dev.sh
AWS_PROFILE="${AWS_PROFILE:-adhito-irmandharu-eks}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../environments/env-development"

echo "Reading Terraform outputs (env-development)..."
INSTANCE_ID=$(terraform -chdir="${TF_DIR}" output -raw bastion_instance_id)
REGION=$(terraform -chdir="${TF_DIR}" output -raw aws_region)

echo ""
echo "Bastion instance : ${INSTANCE_ID}"
echo "Region           : ${REGION}"
echo "AWS profile      : ${AWS_PROFILE}"
echo ""
echo "Opening SSM interactive session (no SSH, no key pair)..."
echo "Tip: run 'kubectl get nodes' immediately. CLUSTER_NAME and AWS_DEFAULT_REGION"
echo "     are pre-set via /etc/bashrc — already active in every SSM session."
echo ""

aws ssm start-session \
  --target "${INSTANCE_ID}" \
  --region "${REGION}" \
  --profile "${AWS_PROFILE}"
