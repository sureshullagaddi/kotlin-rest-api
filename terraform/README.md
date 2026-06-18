# Terraform Infrastructure as Code

Complete Terraform configuration for deploying Fusion API to AWS EKS.

## Directory Structure

```
terraform/
├── README.md                    # This file
├── common.tfvars               # Shared variables across environments
│
├── dev/                         # Development environment
│   ├── terraform.tf            # Backend configuration
│   ├── variables.tf            # Input variables
│   ├── locals.tf               # Local computed values
│   ├── main.tf                 # Resource orchestration
│   ├── outputs.tf              # Output values
│   └── dev.tfvars              # Dev-specific values
│
├── prod/                        # Production environment
│   ├── terraform.tf
│   ├── variables.tf
│   ├── locals.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── prod.tfvars
│
└── modules/                     # Reusable Terraform modules
    ├── eks/                     # EKS cluster module
    ├── rds/                     # RDS PostgreSQL module
    ├── vpc/                     # VPC & networking module
    ├── iam/                     # IAM roles & policies module
    ├── alb/                     # Application Load Balancer module
    └── cloudwatch/              # CloudWatch monitoring module
```

## Quick Start

### Prerequisites

```bash
# Install Terraform
brew install terraform

# Install AWS CLI
brew install awscli

# Configure AWS credentials
aws configure

# Verify AWS access
aws sts get-caller-identity
```

### 1. Initialize Terraform Backend

```bash
# Create S3 bucket and DynamoDB table for state (one-time setup)
./scripts/setup/bootstrap-terraform.sh

# Initialize Terraform with remote backend
cd terraform/dev
terraform init
```

### 2. Plan Infrastructure

```bash
# Review changes that will be applied
cd terraform/dev
terraform plan -var-file=dev.tfvars -out=tfplan
```

### 3. Apply Infrastructure

```bash
# Apply the plan
terraform apply tfplan
```

### 4. Verify Deployment

```bash
# Get cluster credentials
aws eks update-kubeconfig \
  --region us-east-1 \
  --name fusion-api-eks-dev

# Verify EKS cluster
kubectl get nodes
kubectl cluster-info
```

## Configuration Files

### terraform.tf
Configures Terraform backend (S3 + DynamoDB):

```hcl
terraform {
  backend "s3" {
    bucket         = "fusion-hackathon-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "fusion-hackathon-terraform-locks"
  }
}
```

### variables.tf
Defines input variables with descriptions and validation.

### locals.tf
Computes local values using variables and functions.

Example:
```hcl
locals {
  cluster_name = "${var.project}-${var.environment}-eks"
  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}
```

### main.tf
Orchestrates multiple modules to create the complete infrastructure:

```hcl
module "vpc" { ... }
module "eks" { ... }
module "rds" { ... }
module "alb" { ... }
module "iam" { ... }
```

### outputs.tf
Exports values for use in Helm or other purposes:

```hcl
output "eks_cluster_endpoint" { ... }
output "rds_endpoint" { ... }
output "alb_dns_name" { ... }
```

### *.tfvars
Environment-specific variable values:

**dev.tfvars:**
```hcl
environment    = "dev"
node_count     = 2
node_type      = "t3.medium"
db_instance    = "db.t3.micro"
```

**prod.tfvars:**
```hcl
environment    = "prod"
node_count     = 3
node_type      = "m5.large"
db_instance    = "db.m5.large"
```

## Terraform Modules

### eks/ - Elastic Kubernetes Service
Creates EKS cluster with node groups.

**Resources:**
- EKS cluster
- Node groups (auto-scaling)
- VPC integration (via vpc module)
- Security groups
- IAM roles

**Usage:**
```hcl
module "eks" {
  source = "./modules/eks"
  
  cluster_name = var.cluster_name
  node_count   = var.node_count
  node_type    = var.node_type
}
```

### rds/ - Relational Database Service
Creates managed PostgreSQL instance.

**Resources:**
- RDS PostgreSQL instance (multi-AZ)
- DB subnet group
- Security groups
- Parameter groups
- Backup and encryption settings

**Usage:**
```hcl
module "rds" {
  source = "./modules/rds"
  
  instance_class = var.db_instance
  database_name  = "fusion_api"
  username       = var.db_username
}
```

### vpc/ - Virtual Private Cloud
Creates networking infrastructure.

**Resources:**
- VPC with custom CIDR
- Public and private subnets (multi-AZ)
- Internet Gateway
- NAT Gateway
- Route tables
- Network ACLs

**Usage:**
```hcl
module "vpc" {
  source = "./modules/vpc"
  
  cidr_block = "10.0.0.0/16"
  azs        = ["us-east-1a", "us-east-1b"]
}
```

### iam/ - Identity and Access Management
Creates IAM roles and policies.

**Resources:**
- EKS node IAM role
- GitHub Actions OIDC role
- RDS access policies
- CloudWatch permissions

**Usage:**
```hcl
module "iam" {
  source = "./modules/iam"
  
  cluster_name = var.cluster_name
  environment  = var.environment
}
```

### alb/ - Application Load Balancer
Creates load balancer and target groups.

**Resources:**
- Application Load Balancer
- Target groups
- Listeners (HTTP, HTTPS)
- Security groups

**Usage:**
```hcl
module "alb" {
  source = "./modules/alb"
  
  vpc_id    = module.vpc.vpc_id
  subnets   = module.vpc.public_subnets
  domain    = var.domain_name
}
```

### cloudwatch/ - CloudWatch Monitoring
Creates log groups and alarms.

**Resources:**
- Log groups
- Log subscriptions
- CloudWatch alarms
- Dashboards

## Common Operations

### Plan Changes

```bash
cd terraform/{env}
terraform plan -var-file={env}.tfvars
```

### Apply Changes

```bash
# Apply specific resource
terraform apply -target=module.eks -var-file={env}.tfvars

# Apply all changes
terraform apply -var-file={env}.tfvars
```

### Destroy Infrastructure

```bash
# Preview destruction
terraform plan -destroy -var-file={env}.tfvars

# Destroy resources
terraform apply -destroy -var-file={env}.tfvars
```

### Import Existing Resources

```bash
# Import existing AWS resource
terraform import aws_eks_cluster.main fusion-api-eks-prod
```

### State Management

```bash
# Show state
terraform show

# List resources
terraform state list

# Show specific resource
terraform state show module.eks.aws_eks_cluster.main

# Backup state
terraform state pull > state.backup.json

# Lock state (for safety)
terraform state lock
```

## Variables Reference

### Common Variables

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `environment` | string | Environment name | "prod" |
| `project` | string | Project name | "fusion-api" |
| `region` | string | AWS region | "us-east-1" |
| `cluster_name` | string | EKS cluster name | "fusion-api-eks-prod" |

### EKS Variables

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `node_count` | number | Number of nodes | 3 |
| `node_type` | string | EC2 instance type | "m5.large" |
| `kubernetes_version` | string | K8s version | "1.27" |
| `log_retention` | number | CloudWatchLog retention | 30 |

### RDS Variables

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `db_instance` | string | RDS instance class | "db.m5.large" |
| `db_name` | string | Database name | "fusion_api" |
| `db_username` | string | Master username | "postgres" |
| `backup_retention` | number | Backup retention days | 30 |

## Outputs

After `terraform apply`, view outputs:

```bash
terraform output

# Specific output
terraform output eks_cluster_endpoint
```

**Common outputs:**
- `eks_cluster_endpoint` - EKS API endpoint for kubectl
- `rds_endpoint` - RDS database endpoint
- `alb_dns_name` - Load balancer DNS name
- `cloudwatch_log_group` - Log group for application logs

## Best Practices

1. **Always use version constraints:**
   ```hcl
   terraform {
     required_version = ">= 1.5"
     required_providers {
       aws = ">= 5.0"
     }
   }
   ```

2. **Use workspaces for environments:**
   ```bash
   terraform workspace select prod
   ```

3. **Remote state for teams:**
   - Always use S3 + DynamoDB for state locking
   - Never commit `terraform.tfstate` to Git

4. **Code review before apply:**
   - Always run `terraform plan` first
   - Review changes in PRs
   - Require approval for production changes

5. **Use modules for reusability:**
   - Keep modules focused on single responsibility
   - Document module inputs and outputs
   - Version modules if sharing across projects

6. **Secure sensitive data:**
   - Use AWS Secrets Manager for passwords
   - Never log sensitive data
   - Encrypt state backend

7. **Test before production:**
   - Deploy to dev first
   - Run integration tests
   - Verify monitoring and logging

## Troubleshooting

### Terraform Command Issues

```bash
# Check syntax errors
terraform validate

# Format code
terraform fmt -recursive

# Show detailed errors
terraform apply -var-file={env}.tfvars -lock=false
```

### AWS Permission Errors

Ensure your AWS user has necessary permissions:
```bash
aws sts get-caller-identity
```

### State Lock Issues

```bash
# Force unlock (use with caution!)
terraform force-unlock LOCK_ID
```

### Terraform Refactoring

```bash
# Move resources between modules
terraform state mv module.old.resource module.new.resource

# Remove from state (for cleanup)
terraform state rm module.eks.aws_eks_cluster.main
```

## References

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Terraform Language Documentation](https://www.terraform.io/language)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices)
- [AWS EKS Terraform Modules](https://registry.terraform.io/modules/terraform-aws-modules/eks)

## Support

For issues or questions:
1. Check Terraform documentation
2. Review AWS CloudTrail logs for API errors
3. Check CostGuru budget alerts
4. Create issues in GitHub with `terraform` label

