variable "cluster_name" {
  description = "Nombre del clúster EKS"
  type        = string
}

variable "kubernetes_version" {
  description = "Versión de Kubernetes del clúster"
  type        = string
}

variable "cluster_role_arn" {
  description = "ARN del rol IAM para el control plane de EKS (LabRole)"
  type        = string
}

variable "node_role_arn" {
  description = "ARN del rol IAM para el Managed Node Group (LabRole)"
  type        = string
}

variable "subnet_ids" {
  description = "IDs de subredes donde se desplegarán EKS y sus nodos"
  type        = list(string)
}

variable "node_group_name" {
  description = "Nombre del Managed Node Group"
  type        = string
}

variable "instance_types" {
  description = "Lista de tipos de instancia EC2 para los nodos"
  type        = list(string)
}

variable "node_desired_size" {
  description = "Cantidad deseada de nodos"
  type        = number
}

variable "node_min_size" {
  description = "Cantidad mínima de nodos"
  type        = number
}

variable "node_max_size" {
  description = "Cantidad máxima de nodos"
  type        = number
}
