variable "project" {
  description = "Project name"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EC2 will be launched"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where EC2 will be launched"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Key pair name for EC2 instance (null if SSH is not needed)"
  type        = string
  default     = null
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed to access HTTP/HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "backend_secret_arn" {
  description = "ARN of the backend secrets in Secrets Manager"
  type        = string
}

variable "mysql_secret_arn" {
  description = "ARN of the MySQL secrets in Secrets Manager"
  type        = string
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 8
}

# セキュリティとメンテナンス性のための設定変数
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "ecr_repository_name" {
  description = "ECR Repository name for the backend"
  type        = string
  default     = "studify-backend"
}

variable "ebs_device_path" {
  description = "EBS device path"
  type        = string
  default     = "/dev/nvme1n1"
}

variable "mysql_data_dir" {
  description = "MySQL data directory path"
  type        = string
  default     = "/var/lib/mysql"
}

variable "ebs_wait_timeout" {
  description = "EBS volume attachment timeout in seconds"
  type        = number
  default     = 300
}
