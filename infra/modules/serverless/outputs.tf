output "sns_topic_arn" {
  description = "ARN del tópico SNS de alertas"
  value       = aws_sns_topic.alerts.arn
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda de alertas"
  value       = aws_lambda_function.alert_handler.function_name
}

output "lambda_function_arn" {
  description = "ARN de la función Lambda de alertas"
  value       = aws_lambda_function.alert_handler.arn
}
