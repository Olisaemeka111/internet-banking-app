output "namespace_id" {
  description = "ID of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "namespace_name" {
  description = "Name of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "service_registry" {
  description = "Map of service discovery services"
  value = {
    for k, v in aws_service_discovery_service.services : k => {
      id   = v.id
      name = v.name
      arn  = v.arn
    }
  }
}
