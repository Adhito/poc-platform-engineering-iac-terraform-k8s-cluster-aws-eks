output "instance_id" {
  description = "SSM target ID — pass to aws ssm start-session --target"
  value       = aws_instance.bastion.id
}

output "instance_private_ip" {
  description = "Private IP of the bastion (informational)"
  value       = aws_instance.bastion.private_ip
}

output "security_group_id" {
  description = "Security group ID of the bastion host"
  value       = aws_security_group.bastion.id
}

output "iam_role_arn" {
  description = "ARN of the bastion IAM role (used for EKS access entry)"
  value       = aws_iam_role.bastion.arn
}
