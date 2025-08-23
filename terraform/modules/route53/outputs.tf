output "frontend_record_name" {
  description = "Frontend A record name"
  value       = aws_route53_record.frontend.name
}

output "frontend_record_fqdn" {
  description = "Frontend A record FQDN"
  value       = aws_route53_record.frontend.fqdn
}

output "api_record_name" {
  description = "API A record name"
  value       = aws_route53_record.api.name
}

output "api_record_fqdn" {
  description = "API A record FQDN"
  value       = aws_route53_record.api.fqdn
}
