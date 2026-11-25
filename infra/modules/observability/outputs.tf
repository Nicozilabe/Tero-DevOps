output "dashboard_name" {
  description = "Nombre del Dashboard de CloudWatch"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "log_group_name" {
  description = "Nombre del Log Group de CloudWatch de aplicación"
  value       = aws_cloudwatch_log_group.app.name
}

output "alarm_names" {
  description = "Lista de alarmas de CloudWatch configuradas"
  value = [
    aws_cloudwatch_metric_alarm.rds_high_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.rds_low_storage.alarm_name,
    aws_cloudwatch_metric_alarm.rds_high_connections.alarm_name,
  ]
}
