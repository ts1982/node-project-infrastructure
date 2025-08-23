output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "backend_role_arn" {
  description = "ARN of the GitHub Actions backend role"
  value       = aws_iam_role.github_actions_backend.arn
}

output "frontend_role_arn" {
  description = "ARN of the GitHub Actions frontend role"
  value       = aws_iam_role.github_actions_frontend.arn
}

output "backend_role_name" {
  description = "Name of the GitHub Actions backend role"
  value       = aws_iam_role.github_actions_backend.name
}

output "frontend_role_name" {
  description = "Name of the GitHub Actions frontend role"
  value       = aws_iam_role.github_actions_frontend.name
}
