output "cluster_name" {
  description = "Nombre del clúster EKS"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint del API Server de EKS"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Certificado CA del clúster EKS en Base64"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security Group administrado del clúster EKS (usado por los nodos)"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
