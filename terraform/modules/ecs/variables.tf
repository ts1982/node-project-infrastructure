# Common variables
variable "project" {
  description = "Project name"
  type        = string
}

variable "env" {
  description = "Environment name (dev, stg, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

# VPC Configuration
variable "vpc_id" {
  description = "VPC ID where ECS will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed to access HTTP endpoints"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ECS Configuration
variable "task_memory" {
  description = "Total memory for the ECS task (in MB)"
  type        = number
  default     = 768 # Leave ~256MB for ECS agent on t3.micro
}

variable "mysql_memory" {
  description = "Memory allocation for MySQL container (in MB)"
  type        = number
  default     = 256 # Minimal MySQL for testing
}

variable "backend_memory" {
  description = "Memory allocation for backend container (in MB)"
  type        = number
  default     = 512 # Reduced for t3.micro
}

# EC2 Configuration for ECS
variable "instance_type" {
  description = "EC2 instance type for ECS cluster"
  type        = string
  default     = "t3.micro"
}

variable "ecs_optimized_ami" {
  description = "ECS-optimized AMI ID"
  type        = string
  default     = "ami-07722c018a7dc540b" # ECS-optimized Amazon Linux 2 (ap-northeast-1)
}

variable "subnet_id" {
  description = "Subnet ID where ECS instances will be deployed"
  type        = string
}

variable "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret"
  type        = string
}

variable "ebs_volume_id" {
  description = "EBS volume ID for persistent storage"
  type        = string
}

# ECR Configuration
variable "ecr_repository_url" {
  description = "ECR repository URL for the backend application"
  type        = string
}

# MySQL Configuration
variable "mysql_root_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
}

variable "mysql_database" {
  description = "MySQL database name"
  type        = string
}

variable "mysql_user" {
  description = "MySQL application user"
  type        = string
}

variable "mysql_password" {
  description = "MySQL application user password"
  type        = string
  sensitive   = true
}

# Backend Environment Variables
variable "backend_environment_variables" {
  description = "Environment variables for the backend container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# ECR Dependencies
variable "ecr_initial_image_dependency" {
  description = "Dependency to ensure ECR initial image is created before ECS task definition"
  type        = string
  default     = ""
}
