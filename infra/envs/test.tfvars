# Ambiente TEST — Cuenta AWS Academy de Axel (VPC y state aislados de dev)
# Los secretos (ej. TF_VAR_db_password) se inyectan por variables de entorno desde GitHub Environment "test".
aws_region   = "us-east-1"
project_name = "tero"
environment  = "test"

vpc_cidr_block             = "10.20.0.0/16"
public_subnet_cidr_blocks  = ["10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidr_blocks = ["10.20.11.0/24", "10.20.12.0/24"]
azs                        = ["us-east-1a", "us-east-1b"]

kubernetes_version  = "1.35"
node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 3

db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
