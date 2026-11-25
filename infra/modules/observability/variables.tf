variable "name_prefix" {
  description = "Prefijo de proyecto y ambiente"
  type        = string
}

variable "environment" {
  description = "Ambiente actual (dev, test o prod)"
  type        = string
}

variable "aws_region" {
  description = "Región AWS de las métricas del Dashboard"
  type        = string
}

variable "db_instance_identifier" {
  description = "Identificador de la instancia RDS monitoreada"
  type        = string
}

variable "lambda_function_name" {
  description = "Nombre de la función Lambda de alertas monitoreada"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN del tópico SNS donde despachar las alarmas"
  type        = string
}
