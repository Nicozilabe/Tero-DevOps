terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }

  # El bucket y la key se pasan en "terraform init -backend-config=..."
  # siguiendo el patrón de AC2 (bucket tero-tfstate-<account-id>, key <env>/terraform.tfstate).
  backend "s3" {
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Las credenciales se toman del entorno (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY,
# AWS_SESSION_TOKEN) configurado en cada GitHub Environment.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
