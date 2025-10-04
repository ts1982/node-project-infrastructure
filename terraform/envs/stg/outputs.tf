# Infrastructure
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.vpc.public_subnet_id
}

# ECS
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = module.ecs.task_definition_arn
}

# EC2 outputs disabled for Auto Scaling Group (dynamic instances)
# output "ec2_instance_id" {
#   description = "ID of the ECS EC2 instance"
#   value       = module.ecs_ec2.instance_id
# }
# 
# output "ec2_public_ip" {
#   description = "Public IP address of the ECS EC2 instance" 
#   value       = module.ecs_ec2.instance_public_ip
# }
# 
# output "ec2_public_dns" {
#   description = "Public DNS name of the ECS EC2 instance"
#   value       = module.ecs_ec2.instance_public_dns
# }

# ECR
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = module.ecr.repository_name
}

# EBS
output "ebs_volume_id" {
  description = "ID of the EBS volume"
  value       = module.ebs.volume_id
}

# Secrets
output "backend_secret_arn" {
  description = "ARN of the backend secrets"
  value       = module.secrets.backend_secret_arn
  sensitive   = true
}

output "mysql_secret_arn" {
  description = "ARN of the MySQL secrets"
  value       = module.secrets.mysql_secret_arn
  sensitive   = true
}

# Access
output "api_endpoint" {
  description = "API endpoint URL"
  value       = var.api_domain != null ? "https://${var.api_domain}" : "Check ECS service for dynamic instance access"
}

output "direct_ip_access" {
  description = "Direct IP access to the backend API"
  value       = "Use ECS service - instance IPs are dynamic with Auto Scaling Group"
}

# Cost estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    ec2_instance    = "~$8.76 (t3.micro)"
    ebs_storage     = "~$0.08 (1GB gp3)"
    cloudwatch_logs = "~$1-2 (basic logging)"
    total           = "~$10-11/month"
    vs_dev_env      = "Same as dev (t3.micro + 1GB EBS)"
  }
}

# GitHub OIDC
output "github_oidc_role_arn" {
  description = "ARN of the GitHub OIDC IAM role (backend)"
  value       = module.github_oidc.backend_role_arn
}

output "github_oidc_infra_admin_role_arn" {
  description = "ARN of the GitHub OIDC Infrastructure Admin IAM role"
  value       = module.github_oidc.infra_admin_role_arn
}
