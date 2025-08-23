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

# Route53 Outputs
output "frontend_domain" {
  description = "Frontend domain FQDN"
  value       = module.route53.frontend_record_fqdn
}

output "api_domain" {
  description = "API domain FQDN"
  value       = module.route53.api_record_fqdn
}
