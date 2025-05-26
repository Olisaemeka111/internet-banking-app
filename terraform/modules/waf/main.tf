resource "aws_wafv2_web_acl" "main" {
  name        = "${var.environment}-internet-banking-waf"
  description = "WAF Web ACL for Internet Banking API"
  scope       = "REGIONAL"
  
  default_action {
    allow {}
  }
  
  # SQL Injection Rule
  rule {
    name     = "SQLInjectionRule"
    priority = 1
    
    statement {
      or_statement {
        statement {
          sqli_match_statement {
            field_to_match {
              all_query_arguments {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
      }
    }
    
    action {
      block {}
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLInjectionRule"
      sampled_requests_enabled   = true
    }
  }
  
  # XSS Rule
  rule {
    name     = "XSSRule"
    priority = 2
    
    statement {
      or_statement {
        statement {
          xss_match_statement {
            field_to_match {
              body {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
      }
    }
    
    action {
      block {}
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "XSSRule"
      sampled_requests_enabled   = true
    }
  }
  
  # Rate Limiting Rule
  rule {
    name     = "RateLimitRule"
    priority = 3
    
    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }
    
    action {
      block {}
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }
  
  # Geo Restriction Rule (optional - uncomment if needed)
  /*
  rule {
    name     = "GeoRestrictionRule"
    priority = 4
    
    statement {
      geo_match_statement {
        country_codes = var.allowed_countries
      }
    }
    
    action {
      block {}
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoRestrictionRule"
      sampled_requests_enabled   = true
    }
  }
  */
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}-internet-banking-waf"
    sampled_requests_enabled   = true
  }
  
  tags = {
    Name        = "${var.environment}-internet-banking-waf"
    Environment = var.environment
  }
}

# Associate WAF with API Gateway Stage
resource "aws_wafv2_web_acl_association" "api_gateway" {
  resource_arn = var.api_gateway_stage_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# CloudWatch Logging for WAF
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
  
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = "/aws/waf/${var.environment}-internet-banking-waf"
  retention_in_days = 30
  
  tags = {
    Name        = "/aws/waf/${var.environment}-internet-banking-waf"
    Environment = var.environment
  }
}
