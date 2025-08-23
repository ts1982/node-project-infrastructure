variable "project" {
  description = "Project name"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
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

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  type        = string
}

variable "cloudfront_hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID"
  type        = string
}

variable "ec2_public_ip" {
  description = "EC2 instance public IP address"
  type        = string
}

variable "record_ttl" {
  description = "TTL for DNS records"
  type        = number
  default     = 60
}
