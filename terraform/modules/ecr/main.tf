# ECR Repository for Backend
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project}-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # terraform destroy時に強制削除

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
          countNumber = 1 # 最新の1つのみ保持
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

# Create initial placeholder image when ECR repository is empty
resource "null_resource" "initial_image" {
  depends_on = [aws_ecr_repository.backend]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      IMAGE_COUNT=$(aws ecr list-images --repository-name ${aws_ecr_repository.backend.name} --region ${data.aws_region.current.name} --query 'length(imageIds)' --output text 2>/dev/null || echo "0")
      
      if [ "$IMAGE_COUNT" = "0" ]; then
        echo "Creating placeholder image..."
        
        TEMP_DIR=$(mktemp -d)
        cd $TEMP_DIR
        
        cat > Dockerfile << 'EOF'
FROM alpine:3.18
RUN apk add --no-cache netcat-openbsd
EXPOSE 3000
CMD while true; do echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"ok\",\"message\":\"Placeholder backend\",\"environment\":\"staging\"}" | nc -l -p 3000 -q 1; done
EOF
        
        aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${aws_ecr_repository.backend.repository_url}
        docker build --platform linux/amd64 -t ${aws_ecr_repository.backend.repository_url}:latest .
        docker push ${aws_ecr_repository.backend.repository_url}:latest
        
        cd / && rm -rf $TEMP_DIR
        echo "✅ Placeholder image created"
      else
        echo "✅ Repository has $IMAGE_COUNT images"
      fi
    EOT
  }

  triggers = {
    repository_url = aws_ecr_repository.backend.repository_url
  }
}

# Trigger ECS service update when placeholder image is created
resource "null_resource" "trigger_ecs_update" {
  depends_on = [null_resource.initial_image]

  provisioner "local-exec" {
    command = <<-EOT
      if aws ecs describe-services --cluster ${var.cluster_name} --services ${var.service_name} --region ${data.aws_region.current.name} --query 'services[0].serviceName' --output text 2>/dev/null | grep -q "${var.service_name}"; then
        aws ecs update-service --cluster ${var.cluster_name} --service ${var.service_name} --force-new-deployment --region ${data.aws_region.current.name}
        echo "✅ ECS service updated"
      fi
    EOT
  }

  triggers = {
    initial_image_id = null_resource.initial_image.id
  }
}
