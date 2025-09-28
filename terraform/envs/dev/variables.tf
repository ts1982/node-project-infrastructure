variable "project" {
  description = "Project name"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_pair_name" {
  description = "Key pair name for EC2 instance"
  type        = string
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed to access HTTP/HTTPS"
  type        = list(string)
}

# S3 + CloudFront Variables
variable "s3_frontend_bucket" {
  description = "S3 bucket name for frontend"
  type        = string
}

variable "frontend_domain" {
  description = "Frontend domain name"
  type        = string
}

variable "api_domain" {
  description = "API domain name"
  type        = string
}

variable "acm_arn_us_east_1" {
  description = "ACM certificate ARN (us-east-1)"
  type        = string
}

# Route53 Variables
variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "record_ttl" {
  description = "TTL for DNS records"
  type        = number
  default     = 60
}

# GitHub OIDC Variables
variable "github_repositories" {
  description = "List of GitHub repositories that can assume this role"
  type        = list(string)
}

variable "github_branches" {
  description = "List of GitHub branches that can assume this role"
  type        = list(string)
  default     = ["main"]
}

# Secrets Variables
variable "backend_secrets" {
  description = "Backend application secrets"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "mysql_secrets" {
  description = "MySQL database secrets"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 8
}

# EBS Variables
variable "ebs_volume_size" {
  description = "Size of the database EBS volume in GB"
  type        = number
  default     = 1
}

variable "ebs_volume_type" {
  description = "Type of EBS volume"
  type        = string
  default     = "gp3"
}

variable "ebs_iops" {
  description = "IOPS for the EBS volume (minimum 100 for gp3)"
  type        = number
  default     = 100
}

variable "ebs_throughput" {
  description = "Throughput for the EBS volume in MB/s"
  type        = number
  default     = 125
}

variable "domain_name" {
  description = "Root domain name for SES verification"
  type        = string
}
