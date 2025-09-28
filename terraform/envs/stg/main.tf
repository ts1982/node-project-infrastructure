# Staging Environment - ECS on EC2 Configuration

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
    key            = "envs/stg/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "studify-terraform-locks"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.env
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "vpc" {
  source = "../../modules/vpc"

  project            = var.project
  env                = var.env
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = var.availability_zone
}

module "secrets" {
  source = "../../modules/secrets"

  project             = var.project
  env                 = var.env
  backend_secret_name = "backend"
  mysql_secret_name   = "mysql"
  backend_secrets     = var.backend_secrets
  mysql_secrets       = var.mysql_secrets
}

module "ecr" {
  source = "../../modules/ecr"

  project      = var.project
  env          = var.env
  cluster_name = "${var.project}-${var.env}"
  service_name = "${var.project}-${var.env}-app"
}

module "ebs" {
  source = "../../modules/ebs"

  project           = var.project
  env               = var.env
  availability_zone = var.availability_zone
  volume_size       = var.ebs_volume_size
  iops              = var.ebs_iops
  throughput        = var.ebs_throughput
}

module "ecs" {
  source = "../../modules/ecs"

  project   = var.project
  env       = var.env
  region    = var.region
  vpc_id    = module.vpc.vpc_id
  vpc_cidr  = var.vpc_cidr
  subnet_id = module.vpc.public_subnet_id

  instance_type     = var.instance_type
  ecs_optimized_ami = var.ecs_optimized_ami

  secrets_manager_arn = module.secrets.backend_secret_arn
  ebs_volume_id       = module.ebs.volume_id

  task_memory    = 1024
  mysql_memory   = 512
  backend_memory = 512

  ecr_repository_url = module.ecr.repository_url

  ecr_initial_image_dependency = module.ecr.initial_image_created

  mysql_root_password = var.mysql_secrets.password
  mysql_database      = var.mysql_secrets.database
  mysql_user          = var.mysql_secrets.username
  mysql_password      = var.mysql_secrets.password

  backend_environment_variables = [
    {
      name  = "DATABASE_URL"
      value = "mysql://${var.mysql_secrets.username}:${var.mysql_secrets.password}@mysql:3306/${var.mysql_secrets.database}"
    },
    {
      name  = "JWT_SECRET"
      value = var.backend_secrets.JWT_SECRET
    },
    {
      name  = "CORS_ORIGINS"
      value = var.backend_secrets.CORS_ORIGINS
    },
    {
      name  = "MYSQL_HOST"
      value = "mysql"
    },
    {
      name  = "MYSQL_PORT"
      value = "3306"
    },
    {
      name  = "MYSQL_DATABASE"
      value = var.mysql_secrets.database
    },
    {
      name  = "MYSQL_USERNAME"
      value = var.mysql_secrets.username
    },
    {
      name  = "MYSQL_PASSWORD"
      value = var.mysql_secrets.password
    }
  ]

  allowed_http_cidrs = var.allowed_http_cidrs
}

# CloudFront API Module with Route53-based dynamic origin
module "cloudfront_api" {
  count  = var.api_domain != null && var.acm_arn_us_east_1 != null ? 1 : 0
  source = "../../modules/cloudfront_api"

  project    = var.project
  env        = var.env
  api_domain = var.api_domain
  # Route53レコードをオリジンとして使用 - Lambda関数がレコードを動的更新
  ec2_public_ip       = length(data.aws_instances.ecs) > 0 && length(data.aws_instances.ecs[0].public_ips) > 0 ? data.aws_instances.ecs[0].public_ips[0] : "198.51.100.1"
  ec2_public_dns      = "backend-${var.env}.studify.click" # Route53レコード
  acm_certificate_arn = var.acm_arn_us_east_1

  depends_on = [module.ecs, aws_route53_record.ecs_backend]
}

# Route53 Records for API domain
resource "aws_route53_record" "api" {
  count   = var.api_domain != null && var.route53_zone_id != null && length(module.cloudfront_api) > 0 ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.api_domain
  type    = "A"

  alias {
    name                   = module.cloudfront_api[0].cloudfront_domain_name
    zone_id                = module.cloudfront_api[0].cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# Data sources for dynamic instance discovery
data "aws_ecs_cluster" "main" {
  count        = var.api_domain != null && var.route53_zone_id != null ? 1 : 0
  cluster_name = module.ecs.cluster_name

  depends_on = [module.ecs]
}

data "aws_autoscaling_group" "ecs" {
  count = var.api_domain != null && var.route53_zone_id != null ? 1 : 0
  name  = module.ecs.autoscaling_group_name

  depends_on = [module.ecs]
}

# Get ECS instances by Auto Scaling Group tag
data "aws_instances" "ecs" {
  count = var.api_domain != null && var.route53_zone_id != null ? 1 : 0

  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [module.ecs.autoscaling_group_name]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [module.ecs]
}

# Internal Route53 record for ECS backend - dynamically updated by Lambda
resource "aws_route53_record" "ecs_backend" {
  count   = var.api_domain != null && var.route53_zone_id != null ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "backend-${var.env}.studify.click"
  type    = "A"
  ttl     = 60

  # Initial value from discovered ECS instances  
  records = length(data.aws_instances.ecs) > 0 && length(data.aws_instances.ecs[0].public_ips) > 0 ? [data.aws_instances.ecs[0].public_ips[0]] : ["198.51.100.1"]

  lifecycle {
    ignore_changes = [records] # Ignore Lambda function updates
  }
}

resource "aws_route53_record" "api_ipv6" {
  count   = var.api_domain != null && var.route53_zone_id != null && length(module.cloudfront_api) > 0 ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.api_domain
  type    = "AAAA"

  alias {
    name                   = module.cloudfront_api[0].cloudfront_domain_name
    zone_id                = module.cloudfront_api[0].cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

module "github_oidc" {
  source = "../../modules/github_oidc"

  project                     = var.project
  env                         = var.env
  github_repositories         = var.github_repositories
  github_branches             = var.github_branches
  backend_secret_arn          = module.secrets.backend_secret_arn
  mysql_secret_arn            = module.secrets.mysql_secret_arn
  s3_bucket_arn               = "arn:aws:s3:::dummy-bucket"
  cloudfront_distribution_arn = length(module.cloudfront_api) > 0 ? module.cloudfront_api[0].cloudfront_arn : "arn:aws:cloudfront::distribution/dummy"
}
