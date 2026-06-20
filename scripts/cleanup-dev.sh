#!/bin/bash
# ---------------------------------------------------------------------------
# cleanup-dev.sh
# Destroys all Terraform-managed resources in env-development and prints
# instructions for removing the S3 backend bucket.
#
# Run from the REPO ROOT.
# ---------------------------------------------------------------------------
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../environments/env-development"

echo "============================================="
echo "  EKS Platform — env-development Cleanup"
echo "============================================="
echo ""

# ---------------------------------------------------------------------------
# Step 1: Terraform destroy
# ---------------------------------------------------------------------------
echo "[Step 1] Destroying Terraform-managed resources..."
echo "  Working directory: ${TF_DIR}"
echo ""
terraform -chdir="${TF_DIR}" destroy
echo ""
echo "[Step 1] Done."
echo ""

# ---------------------------------------------------------------------------
# Step 2: Manual cleanup of S3 backend bucket
# ---------------------------------------------------------------------------
echo "============================================="
echo "  Manual steps (only if you want to fully"
echo "  remove the remote state infrastructure)"
echo "============================================="
echo ""
echo "  # 1. Delete all objects in the state bucket:"
echo "  aws s3 rm s3://eks-tf-state-env-development --recursive"
echo ""
echo "  # 2. Delete the bucket:"
echo "  aws s3api delete-bucket --bucket eks-tf-state-env-development --region ap-southeast-3"
echo ""
echo "============================================="
echo ""
echo "  # --- Bootstrap commands (for reference) ---"
echo "  # Create S3 bucket:"
echo "  aws s3api create-bucket \\"
echo "    --bucket eks-tf-state-env-development \\"
echo "    --region ap-southeast-3 \\"
echo "    --create-bucket-configuration LocationConstraint=ap-southeast-3"
echo "  aws s3api put-bucket-versioning \\"
echo "    --bucket eks-tf-state-env-development \\"
echo "    --versioning-configuration Status=Enabled"
echo "============================================="
