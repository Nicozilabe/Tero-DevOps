variable "aws_region" {
  description = "Región AWS donde se despliega la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo base del proyecto para nombrar recursos"
  type        = string
  default     = "tero"
}

variable "environment" {
  description = "Ambiente objetivo de despliegue (dev, test o prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "El ambiente debe ser dev, test o prod."
  }
}

variable "vpc_cidr_block" {
  description = "Bloque CIDR principal de la VPC"
  type        = string
}

variable "public_subnet_cidr_blocks" {
  description = "Bloques CIDR de las subredes públicas (EKS y ALB)"
  type        = list(string)
}

variable "private_subnet_cidr_blocks" {
  description = "Bloques CIDR de las subredes privadas (RDS)"
  type        = list(string)
}

variable "azs" {
  description = "Zonas de disponibilidad utilizadas por las subredes"
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Versión de Kubernetes del clúster EKS"
  type        = string
  default     = "1.35"
}

variable "node_instance_types" {
  description = "Tipos de instancia EC2 para el Managed Node Group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Cantidad deseada de nodos en el Managed Node Group"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Cantidad mínima de nodos en el Managed Node Group"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Cantidad máxima de nodos en el Managed Node Group"
  type        = number
  default     = 3
}

variable "ecr_services" {
  description = "Lista de microservicios con repositorio ECR dedicado"
  type        = list(string)
  default     = ["ui", "admin", "catalog", "carts", "orders", "checkout"]
}

variable "db_instance_class" {
  description = "Clase de instancia RDS PostgreSQL"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Almacenamiento inicial en GiB para RDS"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Nombre de la base de datos inicial en RDS"
  type        = string
  default     = "ordersdb"
}

variable "db_username" {
  description = "Usuario maestro de PostgreSQL en RDS"
  type        = string
  default     = "tero_admin"
}

variable "db_password" {
  description = "Contraseña maestra de PostgreSQL en RDS (inyectada por env var TF_VAR_db_password)"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email opcional para suscribir al tópico SNS de alertas"
  type        = string
  default     = ""
}

variable "alert_webhook_url" {
  description = "URL HTTPS opcional de webhook (Discord/Slack) para reenviar alertas desde Lambda"
  type        = string
  sensitive   = true
  default     = ""
}
