# Ambiente DEV — Cuenta AWS Academy de Axel
# Los secretos (ej. TF_VAR_db_password) se inyectan por variables de entorno desde GitHub Environment "dev".
aws_region   = "us-east-1"
project_name = "tero"
environment  = "dev"

vpc_cidr_block             = "10.10.0.0/16"
public_subnet_cidr_blocks  = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidr_blocks = ["10.10.11.0/24", "10.10.12.0/24"]
azs                        = ["us-east-1a", "us-east-1b"]

kubernetes_version  = "1.35"
node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 3

db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
