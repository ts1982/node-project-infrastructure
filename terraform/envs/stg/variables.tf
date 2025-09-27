# Common
variable "project" {
  description = "Project name"
  type        = string
  default     = "studify"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "stg"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

# VPC
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for resources"
  type        = string
}

# EC2
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ecs_optimized_ami" {
  description = "ECS-optimized AMI ID"
  type        = string
  default     = "ami-07722c018a7dc540b"
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access (optional)"
  type        = string
  default     = null
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed to access HTTP endpoints"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "root_volume_size" {
  description = "Size of the root EBS volume (GB)"
  type        = number
  default     = 30
}

# EBS
variable "ebs_volume_size" {
  description = "Size of the EBS volume for database storage (GB)"
  type        = number
  default     = 1
}

variable "ebs_iops" {
  description = "IOPS for the EBS volume"
  type        = number
  default     = 3000
}

variable "ebs_throughput" {
  description = "Throughput for the EBS volume (MB/s)"
  type        = number
  default     = 125
}

# Route53
variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = null
}

variable "api_domain" {
  description = "API domain name"
  type        = string
  default     = null
}

variable "record_ttl" {
  description = "TTL for DNS records"
  type        = number
  default     = 300
}

variable "acm_arn_us_east_1" {
  description = "ACM certificate ARN in us-east-1 for CloudFront"
  type        = string
  default     = null
}

# GitHub OIDC
variable "github_repository" {
  description = "GitHub repository in format owner/repo"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch for OIDC"
  type        = string
  default     = "main"
}

# Backend secrets
variable "backend_secrets" {
  description = "Backend application secrets"
  type = object({
    JWT_SECRET   = string
    API_PORT     = string
    NODE_ENV     = string
    CORS_ORIGINS = string
  })
  sensitive = true
}

# MySQL secrets
variable "mysql_secrets" {
  description = "MySQL database secrets"
  type = object({
    username = string
    password = string
    database = string
    host     = string
    port     = string
  })
  sensitive = true
}
