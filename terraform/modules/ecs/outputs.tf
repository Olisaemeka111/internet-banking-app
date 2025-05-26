output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_services" {
  description = "Map of ECS services"
  value = merge(
    { for k, v in local.public_services : k => {
      id   = aws_ecs_service.public[k].id
      name = aws_ecs_service.public[k].name
      arn  = aws_ecs_service.public[k].cluster
    } },
    { for k, v in local.private_services : k => {
      id   = aws_ecs_service.private[k].id
      name = aws_ecs_service.private[k].name
      arn  = aws_ecs_service.private[k].cluster
    } }
  )
}

output "public_lb_dns" {
  description = "DNS name of the public load balancer"
  value       = aws_lb.public.dns_name
}

output "public_lb_zone_id" {
  description = "Zone ID of the public load balancer"
  value       = aws_lb.public.zone_id
}

output "internal_lb_dns" {
  description = "DNS name of the internal load balancer"
  value       = aws_lb.internal.dns_name
}

output "network_lb_arn" {
  description = "ARN of the Network Load Balancer for API Gateway VPC Link"
  value       = aws_lb.network.arn
}
