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
