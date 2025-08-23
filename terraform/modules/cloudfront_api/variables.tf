variable "project" {
  description = "Project name"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "api_domain" {
  description = "API domain name"
  type        = string
}

variable "ec2_public_ip" {
  description = "EC2 instance public IP address"
  type        = string
}

variable "ec2_public_dns" {
  description = "EC2 instance public DNS name"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}
