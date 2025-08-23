output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.vpc.public_subnet_id
}

output "public_subnet_cidr" {
  description = "CIDR block of the public subnet"
  value       = module.vpc.public_subnet_cidr
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

# EC2 Outputs
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.ec2.instance_id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2.instance_public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = module.ec2.instance_private_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = module.ec2.security_group_id
}

# S3 + CloudFront Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.s3_cloudfront.s3_bucket_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.s3_cloudfront.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.s3_cloudfront.cloudfront_domain_name
}

# API CloudFront Outputs
output "api_cloudfront_distribution_id" {
  description = "ID of the API CloudFront distribution"
  value       = module.cloudfront_api.cloudfront_distribution_id
}

output "api_cloudfront_domain_name" {
  description = "Domain name of the API CloudFront distribution"  
  value       = module.cloudfront_api.cloudfront_domain_name
}

# Route53 Outputs
output "frontend_domain" {
  description = "Frontend domain FQDN"
  value       = module.route53.frontend_record_fqdn
}

output "api_domain" {
  description = "API domain FQDN"
  value       = module.route53.api_record_fqdn
}

# ECR Outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = module.ecr.repository_arn
}

# Secrets Manager Outputs
output "backend_secret_arn" {
  description = "ARN of the backend secrets"
  value       = module.secrets.backend_secret_arn
}

output "mysql_secret_arn" {
  description = "ARN of the MySQL secrets"
  value       = module.secrets.mysql_secret_arn
}

# GitHub OIDC Outputs
output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = module.github_oidc.github_oidc_provider_arn
}

output "backend_role_arn" {
  description = "ARN of the GitHub Actions backend role"
  value       = module.github_oidc.backend_role_arn
}

output "frontend_role_arn" {
  description = "ARN of the GitHub Actions frontend role"
  value       = module.github_oidc.frontend_role_arn
}
