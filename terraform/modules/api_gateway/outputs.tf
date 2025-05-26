output "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "api_gateway_invoke_url" {
  description = "Invoke URL for the API Gateway"
  value       = "${aws_api_gateway_deployment.main.invoke_url}${aws_api_gateway_stage.main.stage_name}"
}

output "api_gateway_dns" {
  description = "Custom domain name for the API Gateway"
  value       = var.domain_name != null ? aws_api_gateway_domain_name.main[0].regional_domain_name : null
}

output "api_gateway_zone_id" {
  description = "Route 53 zone ID for the API Gateway custom domain"
  value       = var.domain_name != null ? aws_api_gateway_domain_name.main[0].regional_zone_id : null
}
