output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_data" {
  description = "Base64-encoded CA certificate for the EKS cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider (for IRSA service accounts)"
  value       = module.eks.oidc_provider_arn
}

output "node_security_group_id" {
  description = "Security group ID attached to the worker nodes"
  value       = module.eks.node_security_group_id
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane"
  value       = module.eks.cluster_security_group_id
}

# ---------------------------------------------------------------------------
# Map of node-group key → Auto Scaling Group name
# The scheduler module uses this to scale nodes up/down via the ASG API
# ---------------------------------------------------------------------------

output "node_group_asg_names" {
  description = "Map of managed node group index to its ASG name"
  value = {
    for idx, asg_name in module.eks.eks_managed_node_groups_autoscaling_group_names :
    tostring(idx) => asg_name
  }
}
