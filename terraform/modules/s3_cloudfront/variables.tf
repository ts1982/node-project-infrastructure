variable "project" {
  description = "Project name"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for frontend"
  type        = string
}

variable "domain_name" {
  description = "Domain name for CloudFront distribution"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for CloudFront (must be in us-east-1)"
  type        = string
}
