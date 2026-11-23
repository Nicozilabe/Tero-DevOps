output "db_instance_identifier" {
  description = "Identificador de la instancia RDS"
  value       = aws_db_instance.this.identifier
}

output "db_endpoint" {
  description = "Endpoint completo (host:puerto) de RDS"
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Hostname privado de RDS"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Puerto TCP de RDS"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Nombre de la base inicial"
  value       = aws_db_instance.this.db_name
}

output "security_group_id" {
  description = "ID del Security Group de RDS"
  value       = aws_security_group.rds.id
}
