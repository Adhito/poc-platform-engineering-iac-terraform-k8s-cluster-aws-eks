output "node_group_config" {
  description = "Managed node group configuration map — passed directly to the EKS community module"
  value       = local.managed_node_groups
}

output "node_role_arn" {
  description = "ARN of the node IAM role (informational)"
  value       = aws_iam_role.node.arn
}
