resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.environment}.internal"
  description = "Service discovery namespace for Internet Banking Microservices"
  vpc         = var.vpc_id
  
  tags = {
    Name        = "${var.environment}.internal"
    Environment = var.environment
  }
}

# Create service discovery services for each microservice
resource "aws_service_discovery_service" "services" {
  for_each = var.services
  
  name = each.key
  
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }
  
  health_check_custom_config {
    failure_threshold = 1
  }
  
  tags = {
    Name        = "${var.environment}-${each.key}"
    Environment = var.environment
    Service     = each.key
  }
}
