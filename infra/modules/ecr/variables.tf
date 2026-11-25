variable "name_prefix" {
  description = "Prefijo de proyecto y ambiente para nombrar los repositorios ECR"
  type        = string
}

variable "services" {
  description = "Lista de microservicios con repositorio ECR propio"
  type        = list(string)
}
