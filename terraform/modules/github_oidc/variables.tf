variable "project" {
  description = "Project name"
  type        = string
  default     = "studify"
}

variable "env" {
  description = "Environment"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in the format owner/repo"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch for OIDC trust (default: main)"
  type        = string
  default     = "main"
}

variable "backend_secret_arn" {
  description = "ARN of the backend secrets"
  type        = string
}

variable "mysql_secret_arn" {
  description = "ARN of the MySQL secrets"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for frontend"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  type        = string
}
