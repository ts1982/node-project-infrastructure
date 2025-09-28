# Data sources
data "aws_caller_identity" "current" {}

# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name        = "${var.project}-${var.env}-github-oidc"
    Project     = var.project
    Environment = var.env
  }
}

# Local variables for multi-repo support
locals {
  # Create all combinations of repo:branch:ref and repo:environment patterns
  repo_branch_refs = flatten([
    for repo in var.github_repositories : [
      for branch in var.github_branches : [
        "repo:${repo}:ref:refs/heads/${branch}",
        "repo:${repo}:environment:${var.env}"
      ]
    ]
  ])
}

# IAM Role for GitHub Actions (Backend)

resource "aws_iam_role" "github_actions_backend" {
  name = "${var.project}-${var.env}-github-actions-backend"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.repo_branch_refs
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-github-actions-backend"
    Project     = var.project
    Environment = var.env
  }
}

# IAM Policy for Backend CI/CD
resource "aws_iam_policy" "github_actions_backend" {
  name        = "${var.project}-${var.env}-github-actions-backend"
  description = "Policy for GitHub Actions Backend CI/CD"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:DeleteSecret"
        ]
        Resource = [
          var.backend_secret_arn,
          var.mysql_secret_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations",
          "ssm:DescribeInstanceInformation"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeClusters",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:ListContainerInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-${var.env}-ecs-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::studify-terraform-state-ap-northeast-1",
          "arn:aws:s3:::studify-terraform-state-ap-northeast-1/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:ap-northeast-1:099355342767:table/studify-terraform-locks"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:ListDistributions",
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:UpdateDistribution",
          "cloudfront:ListTagsForResource",
          "cloudfront:DeleteDistribution"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:ListRoles",
          "iam:PassRole",
          "iam:ListRolePolicies",
          "iam:GetPolicy",
          "iam:GetOpenIDConnectProvider",
          "iam:ListPolicies",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:GetPolicyVersion",
          "iam:GetInstanceProfile",
          "iam:DeleteRolePolicy",
          "iam:DetachRolePolicy",
          "iam:DeleteRole",
          "iam:DeletePolicy",
          "iam:DeleteInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "ecs:*",
          "ec2:*",
          "autoscaling:*",
          "logs:*",
          "route53:*",
          "lambda:*",
          "events:*",
          "ecr:ListTagsForResource",
          "ecr:GetLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:DeleteRepository"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetResourcePolicy"
        ]
        Resource = [
          var.backend_secret_arn,
          var.mysql_secret_arn
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-github-actions-backend-policy"
    Project     = var.project
    Environment = var.env
  }
}

# Attach policy to backend role
resource "aws_iam_role_policy_attachment" "github_actions_backend" {
  role       = aws_iam_role.github_actions_backend.name
  policy_arn = aws_iam_policy.github_actions_backend.arn
}

# IAM Role for GitHub Actions (Frontend)
resource "aws_iam_role" "github_actions_frontend" {
  name = "${var.project}-${var.env}-github-actions-frontend"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.repo_branch_refs
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-github-actions-frontend"
    Project     = var.project
    Environment = var.env
  }
}

# IAM Policy for Frontend CI/CD
resource "aws_iam_policy" "github_actions_frontend" {
  name        = "${var.project}-${var.env}-github-actions-frontend"
  description = "Policy for GitHub Actions Frontend CI/CD"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:ListDistributions"
        ]
        Resource = "*" # CloudFrontのCreateInvalidationとListDistributionsは特定のリソースARNをサポートしていない
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-github-actions-frontend-policy"
    Project     = var.project
    Environment = var.env
  }
}

# Attach policy to frontend role
resource "aws_iam_role_policy_attachment" "github_actions_frontend" {
  role       = aws_iam_role.github_actions_frontend.name
  policy_arn = aws_iam_policy.github_actions_frontend.arn
}
