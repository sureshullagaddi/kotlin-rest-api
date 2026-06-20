###############################################################################
# Bootstrap: One-time setup of Terraform remote backend resources
#
# This config uses a LOCAL backend intentionally — it must run before the
# remote S3/DynamoDB backend exists. Run this ONCE via the bootstrap workflow.
# After running, commit the local state or simply treat this as ephemeral
# (the real resources persist in AWS regardless).
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Intentionally no remote backend — this IS the bootstrap
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# S3 Bucket — Terraform remote state storage
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_bucket

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "Terraform State"
    ManagedBy   = "bootstrap"
    Environment = "shared"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# DynamoDB Table — Terraform state locking
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "Terraform State Locks"
    ManagedBy   = "bootstrap"
    Environment = "shared"
  }
}

