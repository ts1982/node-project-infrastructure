# Route53 A record for frontend (CloudFront)
resource "aws_route53_record" "frontend" {
  zone_id = var.route53_zone_id
  name    = var.frontend_domain
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 AAAA record for frontend (CloudFront IPv6)
resource "aws_route53_record" "frontend_ipv6" {
  zone_id = var.route53_zone_id
  name    = var.frontend_domain
  type    = "AAAA"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 A record for API (EC2 - will be updated by Lambda)
resource "aws_route53_record" "api" {
  zone_id = var.route53_zone_id
  name    = var.api_domain
  type    = "A"
  ttl     = var.record_ttl
  records = [var.ec2_public_ip]
}
