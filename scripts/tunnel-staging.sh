#!/bin/bash
# ---------------------------------------------------------------------------
# tunnel-staging.sh  —  Method 2: SSM port-forward tunnel + local kubectl
#
# Tunnels the EKS private API endpoint (port 443) to localhost:6443 via the
# bastion. kubectl runs locally; the tunnel keeps the connection open.
#
# Usage:
#   bash scripts/tunnel-staging.sh          # starts tunnel, blocks until Ctrl-C
#
# In another terminal while tunnel is running:
#   KUBECONFIG=~/.kube/config-eks-staging-tunnel kubectl get nodes
#   KUBECONFIG=~/.kube/config-eks-staging-tunnel kubectl get pods -A
#
# Note: the tunnel kubeconfig uses insecure-skip-tls-verify because the EKS
#       TLS cert is issued for the real endpoint hostname, not localhost.
#       This is acceptable for a POC / dev environment.
#
# NOTE: Requires the bastion module to be present in environments/env-staging/main.tf
#       and bastion_instance_id output in environments/env-staging/outputs.tf.
# ---------------------------------------------------------------------------
set -e

# AWS CLI named profile. Override before running if your profile name differs:
#   AWS_PROFILE=my-profile bash scripts/tunnel-staging.sh
AWS_PROFILE="${AWS_PROFILE:-adhito-irmandharu-eks}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../environments/env-staging"
TUNNEL_KUBECONFIG="${HOME}/.kube/config-eks-staging-tunnel"
LOCAL_PORT=6443

echo "Reading Terraform outputs (env-staging)..."
INSTANCE_ID=$(terraform -chdir="${TF_DIR}" output -raw bastion_instance_id)
CLUSTER_NAME=$(terraform -chdir="${TF_DIR}" output -raw cluster_name)
REGION=$(terraform -chdir="${TF_DIR}" output -raw aws_region)
EKS_ENDPOINT=$(terraform -chdir="${TF_DIR}" output -raw cluster_endpoint | sed 's|https://||')

echo ""
echo "Bastion instance : ${INSTANCE_ID}"
echo "Cluster          : ${CLUSTER_NAME}"
echo "Region           : ${REGION}"
echo "EKS endpoint     : ${EKS_ENDPOINT}"
echo "Local port       : ${LOCAL_PORT}"
echo "AWS profile      : ${AWS_PROFILE}"
echo ""
echo "Starting SSM port-forward tunnel..."

aws ssm start-session \
  --target "${INSTANCE_ID}" \
  --region "${REGION}" \
  --profile "${AWS_PROFILE}" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${EKS_ENDPOINT}\"],\"portNumber\":[\"443\"],\"localPortNumber\":[\"${LOCAL_PORT}\"]}" &

TUNNEL_PID=$!
echo "Tunnel PID: ${TUNNEL_PID} — waiting 3s for connection to establish..."
sleep 3

# Build a dedicated kubeconfig pointing to localhost:6443
echo "Generating tunnel kubeconfig at ${TUNNEL_KUBECONFIG}..."
aws eks update-kubeconfig \
  --name "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --profile "${AWS_PROFILE}" \
  --kubeconfig "${TUNNEL_KUBECONFIG}"

# Patch server URL to localhost and enable TLS skip (cert CN ≠ localhost)
sed -i "s|server: https://.*|server: https://localhost:${LOCAL_PORT}|" \
  "${TUNNEL_KUBECONFIG}"

# Insert insecure-skip-tls-verify after the server line
sed -i '/server: https:\/\/localhost/a\    insecure-skip-tls-verify: true' \
  "${TUNNEL_KUBECONFIG}"

# Remove certificate-authority-data (conflicts with insecure-skip-tls-verify)
sed -i '/certificate-authority-data:/d' "${TUNNEL_KUBECONFIG}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Tunnel is live on localhost:${LOCAL_PORT}"
echo ""
echo " In another terminal:"
echo "   KUBECONFIG=${TUNNEL_KUBECONFIG} kubectl get nodes"
echo "   KUBECONFIG=${TUNNEL_KUBECONFIG} kubectl get pods -A"
echo ""
echo " Press Ctrl-C to stop the tunnel."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Block until user interrupts
wait "${TUNNEL_PID}"
