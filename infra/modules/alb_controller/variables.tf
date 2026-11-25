variable "cluster_name" {
  description = "Nombre del clúster EKS destino"
  type        = string
}

variable "aws_region" {
  description = "Región AWS donde opera el controller"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC asociada al clúster EKS"
  type        = string
}
