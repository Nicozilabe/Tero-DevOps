variable "name_prefix" {
  description = "Prefijo de proyecto y ambiente"
  type        = string
}

variable "environment" {
  description = "Ambiente actual (dev, test o prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se crea el Security Group de RDS"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs de las subredes privadas para el DB Subnet Group"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security Groups autorizados a conectarse al puerto 5432 de RDS"
  type        = list(string)
}

variable "db_instance_class" {
  description = "Tipo de instancia RDS"
  type        = string
}

variable "db_allocated_storage" {
  description = "Almacenamiento en GiB para RDS"
  type        = number
}

variable "db_name" {
  description = "Nombre de la base inicial en RDS"
  type        = string
}

variable "db_username" {
  description = "Usuario maestro de RDS"
  type        = string
}

variable "db_password" {
  description = "Contraseña maestra de RDS"
  type        = string
  sensitive   = true
}
