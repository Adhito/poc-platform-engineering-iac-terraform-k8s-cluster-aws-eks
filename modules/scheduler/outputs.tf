output "start_lambda_arn" {
  description = "ARN of the start Lambda function (use for manual testing with aws lambda invoke)"
  value       = var.enabled ? aws_lambda_function.start[0].arn : null
}

output "stop_lambda_arn" {
  description = "ARN of the stop Lambda function (use for manual testing with aws lambda invoke)"
  value       = var.enabled ? aws_lambda_function.stop[0].arn : null
}

output "eventbridge_rule_arns" {
  description = "Map of schedule name to EventBridge rule ARN"
  value       = var.enabled ? { for k, v in aws_cloudwatch_event_rule.scheduler : k => v.arn } : {}
}
