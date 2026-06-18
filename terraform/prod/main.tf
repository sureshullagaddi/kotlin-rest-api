# VPC Module
module "vpc" {
  source = "../modules/vpc"

  environment         = var.environment
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones

  public_subnet_tags  = local.public_subnet_tags
  private_subnet_tags = local.private_subnet_tags
  vpc_tags            = local.vpc_tags

  common_tags = local.common_tags
}

# IAM Module
module "iam" {
  source = "../modules/iam"

  cluster_name = local.cluster_name
  environment  = var.environment
  project_name = var.project_name

  common_tags = local.common_tags
}

# EKS Module
module "eks" {
  source = "../modules/eks"

  cluster_name           = local.cluster_name
  kubernetes_version     = var.eks_kubernetes_version
  environment            = var.environment

  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids

  node_group_name = "${local.cluster_name}-nodes"
  node_count      = var.eks_node_count
  node_type       = var.eks_node_type

  eks_node_role_arn = module.iam.eks_node_role_arn

  common_tags = local.common_tags
}

# RDS Module
module "rds" {
  source = "../modules/rds"

  identifier         = "${var.project_name}-db-${var.environment}"
  environment        = var.environment

  vpc_id           = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  instance_class      = var.rds_instance_class
  allocated_storage   = var.rds_allocated_storage
  backup_retention    = var.rds_backup_retention_days

  database_name = "fusion_api"
  username      = var.rds_username
  password      = var.rds_password

  common_tags = local.common_tags
}

# CloudWatch Module
module "cloudwatch" {
  source = "../modules/cloudwatch"

  log_group_name = "/aws/eks/${local.cluster_name}"
  log_retention  = 30
  environment    = var.environment

  common_tags = local.common_tags
}

