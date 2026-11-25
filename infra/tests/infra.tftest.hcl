mock_provider "aws" {
  mock_data "aws_iam_role" {
    defaults = {
      arn  = "arn:aws:iam::123456789012:role/LabRole"
      name = "LabRole"
    }
  }

  mock_data "aws_eks_cluster_auth" {
    defaults = {
      token = "mock-eks-token"
    }
  }

  mock_resource "aws_eks_cluster" {
    defaults = {
      endpoint = "https://mock-eks.us-east-1.eks.amazonaws.com"
      certificate_authority = [
        {
          data = "bW9jay1jYQ=="
        }
      ]
      vpc_config = [
        {
          cluster_security_group_id = "sg-0123456789abcdef0"
        }
      ]
    }
  }

  mock_resource "aws_ecr_repository" {
    defaults = {
      repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/tero-mock"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      address  = "mock-db.internal"
      endpoint = "mock-db.internal:5432"
      port     = 5432
    }
  }
}

mock_provider "helm" {}

run "dev_plan_seguridad_y_aislamiento" {
  command = plan

  variables {
    environment                = "dev"
    vpc_cidr_block             = "10.10.0.0/16"
    public_subnet_cidr_blocks  = ["10.10.1.0/24", "10.10.2.0/24"]
    private_subnet_cidr_blocks = ["10.10.11.0/24", "10.10.12.0/24"]
    azs                        = ["us-east-1a", "us-east-1b"]
    db_password                = "CHANGE_ME_LOCAL_DB_TEST"
  }

  assert {
    condition     = output.cluster_name == "tero-dev"
    error_message = "El nombre del clúster EKS en dev debe ser tero-dev."
  }

  assert {
    condition     = length(output.ecr_repository_urls) == 6
    error_message = "Deben existir 6 repositorios ECR (uno por microservicio)."
  }

  assert {
    condition     = contains(keys(output.ecr_repository_urls), "catalog") && contains(keys(output.ecr_repository_urls), "checkout")
    error_message = "Los repositorios ECR deben incluir catalog y checkout."
  }

  assert {
    condition     = output.cloudwatch_dashboard_name == "tero-dev-dashboard"
    error_message = "El dashboard de CloudWatch debe seguir la convención tero-<env>-dashboard."
  }
}

run "prod_plan_retencion_y_cidr" {
  command = plan

  variables {
    environment                = "prod"
    vpc_cidr_block             = "10.30.0.0/16"
    public_subnet_cidr_blocks  = ["10.30.1.0/24", "10.30.2.0/24"]
    private_subnet_cidr_blocks = ["10.30.11.0/24", "10.30.12.0/24"]
    azs                        = ["us-east-1a", "us-east-1b"]
    node_min_size              = 2
    node_max_size              = 4
    db_password                = "CHANGE_ME_LOCAL_DB_TEST"
  }

  assert {
    condition     = output.cluster_name == "tero-prod"
    error_message = "El nombre del clúster EKS en prod debe ser tero-prod."
  }

  assert {
    condition     = output.lambda_function_name == "tero-prod-alert-handler"
    error_message = "La función Lambda en prod debe llamarse tero-prod-alert-handler."
  }
}

run "modulo_networking_tags_alb_y_cidr" {
  command = plan

  module {
    source = "./modules/networking"
  }

  variables {
    vpc_name           = "tero-dev-vpc"
    vpc_cidr_block     = "10.10.0.0/16"
    public_subnets     = ["10.10.1.0/24", "10.10.2.0/24"]
    private_subnets    = ["10.10.11.0/24", "10.10.12.0/24"]
    availability_zones = ["us-east-1a", "us-east-1b"]
    cluster_name       = "tero-dev"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == "10.10.0.0/16"
    error_message = "La VPC de dev debe usar el bloque CIDR 10.10.0.0/16."
  }

  assert {
    condition     = aws_subnet.public[0].tags["kubernetes.io/role/elb"] == "1"
    error_message = "Las subredes públicas deben tener la etiqueta kubernetes.io/role/elb = 1 para el ALB Controller."
  }

  assert {
    condition     = aws_subnet.private[0].map_public_ip_on_launch == false
    error_message = "Las subredes privadas para RDS no deben asignar IP pública automática."
  }
}

run "modulo_eks_imds_hop_limit" {
  command = plan

  module {
    source = "./modules/eks"
  }

  variables {
    cluster_name       = "tero-dev"
    kubernetes_version = "1.35"
    cluster_role_arn   = "arn:aws:iam::123456789012:role/LabRole"
    node_role_arn      = "arn:aws:iam::123456789012:role/LabRole"
    subnet_ids         = ["subnet-1111", "subnet-2222"]
    node_group_name    = "tero-dev-nodes"
    instance_types     = ["t3.medium"]
    node_desired_size  = 2
    node_min_size      = 1
    node_max_size      = 3
  }

  assert {
    condition     = aws_launch_template.nodes.metadata_options[0].http_put_response_hop_limit == 2
    error_message = "El Launch Template debe fijar hop limit = 2 para compatibilidad de pods con LabRole en AWS Academy."
  }
}

run "modulo_database_seguridad_y_backups" {
  command = plan

  module {
    source = "./modules/database"
  }

  variables {
    name_prefix                = "tero-prod"
    environment                = "prod"
    vpc_id                     = "vpc-123456"
    private_subnet_ids         = ["subnet-priv-1", "subnet-priv-2"]
    allowed_security_group_ids = ["sg-eks-nodes"]
    db_instance_class          = "db.t3.micro"
    db_allocated_storage       = 20
    db_name                    = "ordersdb"
    db_username                = "tero_admin"
    db_password                = "CHANGE_ME_LOCAL_DB_TEST"
  }

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false
    error_message = "RDS nunca debe exponerse públicamente."
  }

  assert {
    condition     = aws_db_instance.this.storage_encrypted == true
    error_message = "RDS debe tener el almacenamiento cifrado habilitado."
  }

  assert {
    condition     = aws_db_instance.this.backup_retention_period == 7
    error_message = "RDS en prod debe conservar 7 días de respaldo automático."
  }
}

run "modulo_observability_tres_alarmas" {
  command = plan

  module {
    source = "./modules/observability"
  }

  variables {
    name_prefix            = "tero-dev"
    environment            = "dev"
    aws_region             = "us-east-1"
    db_instance_identifier = "tero-dev-postgres"
    lambda_function_name   = "tero-dev-alert-handler"
    sns_topic_arn          = "arn:aws:sns:us-east-1:123456789012:tero-dev-alerts"
  }

  assert {
    condition     = aws_cloudwatch_log_group.app.name == "/tero/dev/app"
    error_message = "El Log Group de CloudWatch debe llamarse /tero/dev/app."
  }

  assert {
    condition     = aws_cloudwatch_log_group.app.retention_in_days == 7
    error_message = "En dev la retención de logs debe ser de 7 días para cuidar costos."
  }

  assert {
    condition     = length(output.alarm_names) == 3
    error_message = "Deben configurarse al menos 3 alarmas en CloudWatch."
  }
}

run "rechaza_ambiente_invalido" {
  command = plan

  variables {
    environment                = "staging"
    vpc_cidr_block             = "10.40.0.0/16"
    public_subnet_cidr_blocks  = ["10.40.1.0/24", "10.40.2.0/24"]
    private_subnet_cidr_blocks = ["10.40.11.0/24", "10.40.12.0/24"]
    azs                        = ["us-east-1a", "us-east-1b"]
    db_password                = "CHANGE_ME_LOCAL_DB_TEST"
  }

  expect_failures = [
    var.environment,
  ]
}
