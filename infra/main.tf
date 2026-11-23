locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  cluster_name = local.name_prefix
}

# En AWS Academy Learner Lab no se permite crear roles IAM custom:
# se reutiliza siempre el rol preexistente LabRole.
data "aws_iam_role" "labrole" {
  name = "LabRole"
}

module "networking" {
  source             = "./modules/networking"
  vpc_name           = "${local.name_prefix}-vpc"
  vpc_cidr_block     = var.vpc_cidr_block
  public_subnets     = var.public_subnet_cidr_blocks
  private_subnets    = var.private_subnet_cidr_blocks
  availability_zones = var.azs
  cluster_name       = local.cluster_name
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  cluster_role_arn   = data.aws_iam_role.labrole.arn
  node_role_arn      = data.aws_iam_role.labrole.arn
  subnet_ids         = module.networking.public_subnet_ids
  node_group_name    = "${local.name_prefix}-nodes"
  instance_types     = var.node_instance_types
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size

  # Las rutas a internet deben existir antes de que los nodos se registren en el clúster
  # y mantenerse activas mientras se destruye el Node Group.
  depends_on = [module.networking]
}

module "alb_controller" {
  source       = "./modules/alb_controller"
  cluster_name = module.eks.cluster_name
  aws_region   = var.aws_region
  vpc_id       = module.networking.vpc_id

  # El controller necesita nodos activos para programarse en kube-system.
  depends_on = [module.eks]
}

module "ecr" {
  source      = "./modules/ecr"
  name_prefix = local.name_prefix
  services    = var.ecr_services
}

module "database" {
  source                     = "./modules/database"
  name_prefix                = local.name_prefix
  environment                = var.environment
  vpc_id                     = module.networking.vpc_id
  private_subnet_ids         = module.networking.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
  db_instance_class          = var.db_instance_class
  db_allocated_storage       = var.db_allocated_storage
  db_name                    = var.db_name
  db_username                = var.db_username
  db_password                = var.db_password
}

module "serverless" {
  source            = "./modules/serverless"
  name_prefix       = local.name_prefix
  environment       = var.environment
  lambda_role_arn   = data.aws_iam_role.labrole.arn
  alert_email       = var.alert_email
  alert_webhook_url = var.alert_webhook_url
}

module "observability" {
  source                 = "./modules/observability"
  name_prefix            = local.name_prefix
  environment            = var.environment
  aws_region             = var.aws_region
  db_instance_identifier = module.database.db_instance_identifier
  lambda_function_name   = module.serverless.lambda_function_name
  sns_topic_arn          = module.serverless.sns_topic_arn
}
