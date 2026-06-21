# Current AWS account — used to build IAM role ARNs
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# DB Credentials — fully managed by Terraform
#
# 1. random_password   → generates a strong password (never seen by humans)
# 2. aws_secretsmanager_secret + version → stores username + password as JSON
# 3. RDS module        → uses the values directly from the resources
# 4. terraform destroy → removes all three automatically (clean teardown)
# ---------------------------------------------------------------------------
resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"  # excludes chars that break conn strings
  min_upper        = 4
  min_lower        = 4
  min_numeric      = 4
  min_special      = 4
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "product-service/${var.environment}/db-credentials"
  description             = "RDS credentials for product-service ${var.environment} — managed by Terraform"
  recovery_window_in_days = 0 # Immediate deletion on terraform destroy (no 30-day recovery window)

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.rds_username
    password = random_password.db.result
    host     = module.rds.db_instance_endpoint
    port     = 5432
    dbname   = "fusion_api"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# VPC Module
module "vpc" {
  source = "../modules/vpc"

  environment         = var.environment
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  single_nat_gateway  = false  # prod: one NAT per AZ for high availability

  public_subnet_tags  = local.public_subnet_tags
  private_subnet_tags = local.private_subnet_tags
  vpc_tags            = local.vpc_tags
  common_tags         = local.common_tags
}
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

  eks_node_role_arn      = module.iam.eks_node_role_arn
  eks_cluster_role_arn   = module.iam.eks_cluster_role_arn
  cluster_admin_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/github-actions-oidc-role"

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
  password      = random_password.db.result

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

