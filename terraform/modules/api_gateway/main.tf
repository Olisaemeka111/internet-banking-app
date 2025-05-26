resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.environment}-internet-banking-api"
  description = "API Gateway for Internet Banking Microservices"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  tags = {
    Name = "${var.environment}-internet-banking-api"
  }
}

# API Gateway VPC Link
resource "aws_api_gateway_vpc_link" "main" {
  name        = "${var.environment}-internet-banking-vpc-link"
  description = "VPC Link for Internet Banking API Gateway"
  target_arns = [var.nlb_arn]
  
  tags = {
    Name = "${var.environment}-internet-banking-vpc-link"
  }
}

# Resources and methods for each service
resource "aws_api_gateway_resource" "services" {
  for_each = var.api_services
  
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = each.key
}

resource "aws_api_gateway_resource" "proxy" {
  for_each = var.api_services
  
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.services[each.key].id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  for_each = var.api_services
  
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.proxy[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
  
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Format the target URL for API Gateway integration
locals {
  formatted_urls = {
    for k, v in var.api_services : k => format("http://%s", v.target_url)
  }
}

resource "aws_api_gateway_integration" "proxy" {
  for_each = var.api_services
  
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.proxy[each.key].id
  http_method             = aws_api_gateway_method.proxy[each.key].http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "${local.formatted_urls[each.key]}/{proxy}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.main.id
  
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# Root method for each service
resource "aws_api_gateway_method" "root" {
  for_each = var.api_services
  
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.services[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root" {
  for_each = var.api_services
  
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.services[each.key].id
  http_method             = aws_api_gateway_method.root[each.key].http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "${local.formatted_urls[each.key]}/"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.main.id
}

# Deployment and stage
resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    aws_api_gateway_integration.proxy,
    aws_api_gateway_integration.root
  ]
  
  rest_api_id = aws_api_gateway_rest_api.main.id
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment
  
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format          = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
  
  tags = {
    Name = "${var.environment}-internet-banking-api-stage"
  }
}

# CloudWatch log group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.environment}-internet-banking-api"
  retention_in_days = 30
  
  tags = {
    Name = "/aws/apigateway/${var.environment}-internet-banking-api"
  }
}

# Custom domain name for API Gateway
resource "aws_api_gateway_domain_name" "main" {
  count = var.domain_name != null ? 1 : 0
  
  domain_name              = "api.${var.domain_name}"
  regional_certificate_arn = var.certificate_arn
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  tags = {
    Name = "api.${var.domain_name}"
  }
}

# Base path mapping for custom domain
resource "aws_api_gateway_base_path_mapping" "main" {
  count = var.domain_name != null ? 1 : 0
  
  api_id      = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  domain_name = aws_api_gateway_domain_name.main[0].domain_name
}
