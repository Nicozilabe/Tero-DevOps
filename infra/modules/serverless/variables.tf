variable "name_prefix" {
  description = "Prefijo de proyecto y ambiente"
  type        = string
}

variable "environment" {
  description = "Ambiente actual (dev, test o prod)"
  type        = string
}

variable "lambda_role_arn" {
  description = "ARN del rol IAM preexistente para ejecutar Lambda (LabRole)"
  type        = string
}

variable "alert_email" {
  description = "Dirección de correo opcional para suscribir al tópico SNS"
  type        = string
  default     = ""
}

variable "alert_webhook_url" {
  description = "URL HTTPS opcional de webhook para reenviar alertas enriquecidas"
  type        = string
  sensitive   = true
  default     = ""
}
