# ECR Repository for Backend
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project}-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # terraform destroy時に強制削除

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project}-${var.env}-backend-ecr"
    Project     = var.project
    Environment = var.env
  }
}

# ECR Lifecycle Policy - 最新1つ保持（destroy対応）
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the latest 1 image (survives destroy)"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 1  # 最新の1つのみ保持
        }
        action = {
          type = "expire"
        }
      }
    ]
  })

  # ECRリポジトリより先に削除されないよう依存関係を明示
  depends_on = [aws_ecr_repository.backend]
  
  # destroy時にライフサイクルポリシーを最後に削除
  lifecycle {
    create_before_destroy = false
  }
}

# AWS region data source
data "aws_region" "current" {}
