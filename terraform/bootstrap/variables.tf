variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "eu-north-1"
}

variable "terraform_bucket" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
  default     = "tf-state-397979615352"
}

