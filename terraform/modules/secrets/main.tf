# Generate random IDs for unique secret names
resource "random_id" "backend_secret" {
  keepers = {
    project = var.project
    env     = var.env
  }
  byte_length = 4
}

resource "random_id" "mysql_secret" {
  keepers = {
    project = var.project
    env     = var.env
  }
  byte_length = 4
}

# Secrets Manager Secret for Backend
resource "aws_secretsmanager_secret" "backend" {
  name        = "${var.project}-${var.env}-backend-secret-${random_id.backend_secret.hex}"
  description = "Backend application secrets for ${var.project} ${var.env}"
  
  recovery_window_in_days = 0  # 即座に削除（削除保留なし）

  tags = {
    Name        = "${var.project}-${var.env}-backend-secret"
    Project     = var.project
    Environment = var.env
  }
}

# Backend Secret Version with auto-generated DATABASE_URL
resource "aws_secretsmanager_secret_version" "backend" {
  secret_id = aws_secretsmanager_secret.backend.id
  secret_string = jsonencode(merge(
    var.backend_secrets,
    {
      # MySQLの設定から自動でDATABASE_URLを生成
      DATABASE_URL = "mysql://${var.mysql_secrets["username"]}:${var.mysql_secrets["password"]}@${var.mysql_secrets["host"]}:${var.mysql_secrets["port"]}/${var.mysql_secrets["database"]}"
    }
  ))
}

# Secrets Manager Secret for MySQL
resource "aws_secretsmanager_secret" "mysql" {
  name        = "${var.project}-${var.env}-mysql-secret-${random_id.mysql_secret.hex}"
  description = "MySQL database secrets for ${var.project} ${var.env}"
  
  recovery_window_in_days = 0  # 即座に削除（削除保留なし）

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
