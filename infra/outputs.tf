output "environment" {
  description = "Ambiente desplegado"
  value       = var.environment
}

output "vpc_id" {
  description = "ID de la VPC del ambiente"
  value       = module.networking.vpc_id
}

output "cluster_name" {
  description = "Nombre del clúster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint del API Server de EKS"
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_urls" {
  description = "Mapa de URLs de los repositorios ECR por microservicio"
  value       = module.ecr.repository_urls
}

output "ecr_registry_url" {
  description = "Host base del registro ECR de la cuenta"
  value       = module.ecr.registry_url
}

output "rds_endpoint" {
  description = "Endpoint completo (host:puerto) de RDS PostgreSQL"
  value       = module.database.db_endpoint
}

output "rds_address" {
  description = "Hostname privado de RDS PostgreSQL"
  value       = module.database.db_address
}

output "rds_port" {
  description = "Puerto TCP de RDS PostgreSQL"
  value       = module.database.db_port
}

output "sns_topic_arn" {
  description = "ARN del tópico SNS de alertas operativas"
  value       = module.serverless.sns_topic_arn
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda procesadora de alertas"
  value       = module.serverless.lambda_function_name
}

output "cloudwatch_dashboard_name" {
  description = "Nombre del Dashboard de CloudWatch"
  value       = module.observability.dashboard_name
}

output "kubeconfig_command" {
  description = "Comando para configurar kubectl contra el clúster EKS"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
