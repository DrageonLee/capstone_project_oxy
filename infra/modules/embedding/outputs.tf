###############################################################################
# Embedding Module — Outputs
###############################################################################

output "lambda_arn" {
  description = "ARN of the embedding Lambda function"
  value       = aws_lambda_function.embed.arn
}

output "lambda_name" {
  description = "Name of the embedding Lambda function"
  value       = aws_lambda_function.embed.function_name
}

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.embed.arn
}
