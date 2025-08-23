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
