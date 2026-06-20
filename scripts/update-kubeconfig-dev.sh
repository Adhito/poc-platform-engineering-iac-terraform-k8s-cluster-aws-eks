#!/bin/bash
# ---------------------------------------------------------------------------
# update-kubeconfig-dev.sh
# Run from the REPO ROOT after terraform apply completes (env-development).
# Reads the cluster name from Terraform outputs and configures kubectl.
# ---------------------------------------------------------------------------
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../environments/env-development"

echo "Reading Terraform outputs (env-development)..."
CLUSTER_NAME=$(terraform -chdir="${TF_DIR}" output -raw cluster_name)
REGION=$(terraform -chdir="${TF_DIR}" output -raw aws_region)

echo "Cluster : ${CLUSTER_NAME}"
echo "Region  : ${REGION}"
echo ""
echo "Updating kubeconfig..."
aws eks update-kubeconfig \
  --name "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --profile adhito-irmandharu-eks
echo ""
echo "Done. Verify with:"
echo "  kubectl get nodes"
