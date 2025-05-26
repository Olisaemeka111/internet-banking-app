resource "aws_route53_zone" "main" {
  name = var.domain_name
  
  tags = {
    Name        = var.domain_name
    Environment = var.environment
  }
}

# Record for API Gateway
resource "aws_route53_record" "api" {
  count = var.api_gateway_dns != null ? 1 : 0
  
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"
  
  alias {
    name                   = var.api_gateway_dns
    zone_id                = var.api_gateway_zone_id
    evaluate_target_health = true
  }
}

# Record for main domain (pointing to API Gateway)
resource "aws_route53_record" "main" {
  count = var.api_gateway_dns != null ? 1 : 0
  
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  
  alias {
    name                   = var.api_gateway_dns
    zone_id                = var.api_gateway_zone_id
    evaluate_target_health = true
  }
}

# Record for www subdomain
resource "aws_route53_record" "www" {
  count = var.api_gateway_dns != null ? 1 : 0
  
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  
  alias {
    name                   = var.api_gateway_dns
    zone_id                = var.api_gateway_zone_id
    evaluate_target_health = true
  }
}
