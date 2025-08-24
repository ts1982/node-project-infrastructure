terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "studify-terraform-state-ap-northeast-1"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "studify-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.env
      ManagedBy   = "Terraform"
    }
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project            = var.project
  env                = var.env
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = var.availability_zone
}

# EC2 Module
module "ec2" {
  source = "../../modules/ec2"

  project            = var.project
  env                = var.env
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.public_subnet_id
  instance_type      = var.instance_type
  key_pair_name      = var.key_pair_name
  allowed_http_cidrs = var.allowed_http_cidrs
  backend_secret_arn = module.secrets.backend_secret_arn
  mysql_secret_arn   = module.secrets.mysql_secret_arn
  root_volume_size   = var.root_volume_size
}

# S3 + CloudFront Module
module "s3_cloudfront" {
  source = "../../modules/s3_cloudfront"

  project             = var.project
  env                 = var.env
  bucket_name         = var.s3_frontend_bucket
  domain_name         = var.frontend_domain
  acm_certificate_arn = var.acm_arn_us_east_1
}

# CloudFront API Module (Backend)
module "cloudfront_api" {
  source = "../../modules/cloudfront_api"

  project             = var.project
  env                 = var.env
  api_domain          = var.api_domain
  ec2_public_ip       = module.ec2.instance_public_ip
  ec2_public_dns      = module.ec2.instance_public_dns
  acm_certificate_arn = var.acm_arn_us_east_1
}

# Route53 Module
module "route53" {
  source = "../../modules/route53"

  project                       = var.project
  env                           = var.env
  route53_zone_id               = var.route53_zone_id
  frontend_domain               = var.frontend_domain
  api_domain                    = var.api_domain
  cloudfront_domain_name        = module.s3_cloudfront.cloudfront_domain_name
  cloudfront_hosted_zone_id     = module.s3_cloudfront.cloudfront_hosted_zone_id
  api_cloudfront_domain_name    = module.cloudfront_api.cloudfront_domain_name
  api_cloudfront_hosted_zone_id = module.cloudfront_api.cloudfront_hosted_zone_id
  ec2_public_ip                 = module.ec2.instance_public_ip
  record_ttl                    = var.record_ttl
}

# ECR module
module "ecr" {
  source = "../../modules/ecr"

  project = var.project
  env     = var.env
}

# Secrets Manager module
module "secrets" {
  source = "../../modules/secrets"

  project             = var.project
  env                 = var.env
  backend_secret_name = "${var.project}-${var.env}-backend-secret"
  mysql_secret_name   = "${var.project}-${var.env}-mysql-secret"

  # Secrets from terraform.tfvars
  backend_secrets = var.backend_secrets
  mysql_secrets   = var.mysql_secrets
}

# GitHub OIDC Provider module
module "github_oidc" {
  source = "../../modules/github_oidc"

  project                     = var.project
  env                         = var.env
  github_repository           = var.github_repository
  github_branch               = var.github_branch
  backend_secret_arn          = module.secrets.backend_secret_arn
  mysql_secret_arn            = module.secrets.mysql_secret_arn
  s3_bucket_arn               = module.s3_cloudfront.s3_bucket_arn
  cloudfront_distribution_arn = module.s3_cloudfront.cloudfront_distribution_arn
}
