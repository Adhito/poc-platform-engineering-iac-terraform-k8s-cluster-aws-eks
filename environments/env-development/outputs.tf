# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

# ---------------------------------------------------------------------------
# EKS Cluster
# ---------------------------------------------------------------------------

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_data" {
  description = "Base64-encoded cluster CA certificate"
  value       = module.eks.cluster_ca_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN (for IRSA)"
  value       = module.eks.oidc_provider_arn
}

output "aws_region" {
  description = "AWS region the cluster was deployed into"
  value       = var.aws_region
}

# ---------------------------------------------------------------------------
# Convenience: copy-paste command to configure kubectl
# ---------------------------------------------------------------------------

output "update_kubeconfig_command" {
  description = "Run this command after apply to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

# ---------------------------------------------------------------------------
# Bastion
# ---------------------------------------------------------------------------

output "bastion_instance_id" {
  description = "SSM target ID — used by connect-bastion-dev.sh and tunnel-dev.sh"
  value       = module.bastion.instance_id
}

output "bastion_private_ip" {
  description = "Private IP of the bastion host (informational)"
  value       = module.bastion.instance_private_ip
}

# ---------------------------------------------------------------------------
# Scheduler
# ---------------------------------------------------------------------------

output "scheduler_start_lambda_arn" {
  description = "ARN of the scheduler start Lambda (for manual testing)"
  value       = module.scheduler.start_lambda_arn
}

output "scheduler_stop_lambda_arn" {
  description = "ARN of the scheduler stop Lambda (for manual testing)"
  value       = module.scheduler.stop_lambda_arn
}
