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

# ECR Lifecycle Policy - 即時全削除
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete all images after 1 day for cost optimization"
        selection = {
          tagStatus   = "any"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1  # 1日後に削除
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
