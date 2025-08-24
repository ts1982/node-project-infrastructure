# ECR Repository for Backend
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project}-${var.env}-backend-ecr"
    Project     = var.project
    Environment = var.env
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only 1 latest image (by creation date)"
        selection = {
          tagStatus   = "any"  # タグ有り無し関係なく
          countType   = "imageCountMoreThan"
          countNumber = 1  # 最新の1つのみ保持
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
