# CloudWatch Module - Logging and Monitoring

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "log_retention" {
  description = "Log retention days"
  type        = number
}

variable "environment" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "eks" {
  name              = var.log_group_name
  retention_in_days = var.log_retention

  tags = merge(
    var.common_tags,
    {
      Name = var.log_group_name
    }
  )
}

# CloudWatch Log Stream
resource "aws_cloudwatch_log_stream" "application" {
  name           = "application"
  log_group_name = aws_cloudwatch_log_group.eks.name
}

# Outputs
output "log_group_name" {
  value = aws_cloudwatch_log_group.eks.name
}

output "log_group_arn" {
  value = aws_cloudwatch_log_group.eks.arn
}

output "log_stream_name" {
  value = aws_cloudwatch_log_stream.application.name
}

