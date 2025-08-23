output "backend_secret_arn" {
  description = "ARN of the backend secret"
  value       = aws_secretsmanager_secret.backend.arn
}

output "backend_secret_name" {
  description = "Name of the backend secret"
  value       = aws_secretsmanager_secret.backend.name
}

output "mysql_secret_arn" {
  description = "ARN of the MySQL secret"
  value       = aws_secretsmanager_secret.mysql.arn
}

output "mysql_secret_name" {
  description = "Name of the MySQL secret"
  value       = aws_secretsmanager_secret.mysql.name
}
