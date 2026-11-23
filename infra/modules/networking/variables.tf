variable "vpc_name" {
  description = "Nombre asignado a la VPC y sus recursos de red"
  type        = string
}

variable "vpc_cidr_block" {
  description = "Bloque CIDR principal de la VPC"
  type        = string
}

variable "public_subnets" {
  description = "Lista de CIDRs para las subredes públicas"
  type        = list(string)
}

variable "private_subnets" {
  description = "Lista de CIDRs para las subredes privadas (RDS)"
  type        = list(string)
}

variable "availability_zones" {
  description = "Lista de zonas de disponibilidad (alineada con los CIDRs de subred)"
  type        = list(string)
}

variable "cluster_name" {
  description = "Nombre del clúster EKS para etiquetar las subredes del ALB Controller"
  type        = string
}
