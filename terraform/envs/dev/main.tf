terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

# Route53 Module
module "route53" {
  source = "../../modules/route53"

  project                   = var.project
  env                       = var.env
  route53_zone_id           = var.route53_zone_id
  frontend_domain           = var.frontend_domain
  api_domain                = var.api_domain
  cloudfront_domain_name    = module.s3_cloudfront.cloudfront_domain_name
  cloudfront_hosted_zone_id = module.s3_cloudfront.cloudfront_hosted_zone_id
  ec2_public_ip             = module.ec2.instance_public_ip
  record_ttl                = var.record_ttl
}
