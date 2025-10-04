# Infrastructure Management Role - separate from application role
# This role is used specifically for managing GitHub OIDC infrastructure
# and can safely delete the application roles without affecting itself

resource "aws_iam_role" "github_actions_infra_admin" {
  name = "${var.project}-${var.env}-github-actions-infra-admin"

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
    Name        = "${var.project}-${var.env}-github-actions-infra-admin"
    Project     = var.project
    Environment = var.env
    Purpose     = "Infrastructure Management"
  }
}

# Infrastructure Management Policy
resource "aws_iam_policy" "github_actions_infra_admin" {
  name        = "${var.project}-${var.env}-github-actions-infra-admin"
  description = "Policy for GitHub Actions Infrastructure Management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # S3 for Terraform state
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
          # DynamoDB for Terraform locks
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:ap-northeast-1:099355342767:table/studify-terraform-locks"
      },
      {
        Effect = "Allow"
        Action = [
          # IAM for GitHub OIDC management
          "iam:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          # CloudFormation (if needed)
          "cloudformation:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-github-actions-infra-admin-policy"
    Project     = var.project
    Environment = var.env
    Purpose     = "Infrastructure Management"
  }
}

# Attach policy to infrastructure admin role
resource "aws_iam_role_policy_attachment" "github_actions_infra_admin" {
  role       = aws_iam_role.github_actions_infra_admin.name
  policy_arn = aws_iam_policy.github_actions_infra_admin.arn
}
