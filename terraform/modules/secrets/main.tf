# Secrets Manager Secret for Backend
resource "aws_secretsmanager_secret" "backend" {
  name        = var.backend_secret_name
  description = "Backend application secrets for ${var.project} ${var.env}"

  tags = {
    Name        = "${var.project}-${var.env}-backend-secret"
    Project     = var.project
    Environment = var.env
  }
}

# Backend Secret Version (initial empty version)
resource "aws_secretsmanager_secret_version" "backend" {
  secret_id     = aws_secretsmanager_secret.backend.id
  secret_string = jsonencode(var.backend_secrets)
}

# Secrets Manager Secret for MySQL
resource "aws_secretsmanager_secret" "mysql" {
  name        = var.mysql_secret_name
  description = "MySQL database secrets for ${var.project} ${var.env}"

  tags = {
    Name        = "${var.project}-${var.env}-mysql-secret"
    Project     = var.project
    Environment = var.env
  }
}

# MySQL Secret Version (initial empty version)
resource "aws_secretsmanager_secret_version" "mysql" {
  secret_id     = aws_secretsmanager_secret.mysql.id
  secret_string = jsonencode(var.mysql_secrets)
}
