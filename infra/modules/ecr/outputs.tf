output "repository_urls" {
  description = "Mapa de nombre de servicio a URL del repositorio ECR"
  value       = { for k, repo in aws_ecr_repository.this : k => repo.repository_url }
}

output "registry_url" {
  description = "Hostname base del registro ECR"
  value       = length(aws_ecr_repository.this) > 0 ? split("/", values(aws_ecr_repository.this)[0].repository_url)[0] : ""
}
