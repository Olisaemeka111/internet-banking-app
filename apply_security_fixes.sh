#!/bin/bash

# Security Remediation Script for Internet Banking Application
# This script applies critical security fixes to the infrastructure

set -e

echo "===== Internet Banking Security Remediation ====="
echo "Starting security fixes application..."

# 1. Fix CloudWatch Log Encryption
fix_cloudwatch_encryption() {
  echo "Fixing CloudWatch Log Encryption..."
  
  # Create a directory to store fixed files
  mkdir -p security_fixes/modules
  
  # Fix ECS module
  sed -E 's/(resource "aws_cloudwatch_log_group" "[^"]+" \{)/\1\n  kms_key_id = aws_kms_key.logs.arn/g' \
    terraform/modules/ecs/main.tf > security_fixes/modules/ecs_main.tf
  
  # Fix WAF module
  sed -E 's/(resource "aws_cloudwatch_log_group" "waf" \{)/\1\n  kms_key_id = aws_kms_key.logs.arn/g' \
    terraform/modules/waf/main.tf > security_fixes/modules/waf_main.tf
  
  # Create KMS key resource
  cat > security_fixes/modules/kms.tf << EOF
resource "aws_kms_key" "logs" {
  description             = "\${var.environment} logs encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::\${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Name        = "\${var.environment}-logs-kms-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "logs" {
  name          = "alias/\${var.environment}-logs"
  target_key_id = aws_kms_key.logs.key_id
}
EOF
  
  echo "CloudWatch encryption fixes generated in security_fixes/modules/"
}

# 2. Fix API Gateway Authentication
fix_api_gateway_auth() {
  echo "Fixing API Gateway Authentication..."
  
  # Check if Cognito is already configured
  if grep -q "aws_cognito_user_pool" terraform/modules/api_gateway/main.tf; then
    echo "Cognito appears to be already configured in the API Gateway module."
  else
    # Create Cognito configuration
    cat > security_fixes/modules/api_gateway_cognito.tf << EOF
# Add Cognito User Pool for API Gateway Authorization
resource "aws_cognito_user_pool" "main" {
  name = "\${var.environment}-internet-banking-users"
  
  # Password policy
  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
  
  # MFA configuration
  mfa_configuration = "OPTIONAL"
  
  # Advanced security features
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }
  
  # Auto-verified attributes
  auto_verified_attributes = ["email"]
  
  # Schema attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    mutable             = true
    required            = true
  }
  
  tags = {
    Name        = "\${var.environment}-internet-banking-users"
    Environment = var.environment
  }
}

# Create authorizer for API Gateway
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "\${var.environment}-cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.main.arn]
}

# Update API methods to use Cognito authorizer
resource "aws_api_gateway_method" "api_method" {
  # Note: This resource needs to be updated in the main module file
  # authorization = "COGNITO_USER_POOLS"
  # authorizer_id = aws_api_gateway_authorizer.cognito.id
}
EOF
    
    echo "Generated Cognito configuration in security_fixes/modules/api_gateway_cognito.tf"
    echo "NOTE: You'll need to update the API Gateway methods manually to use the Cognito authorizer"
  fi
}

# 3. Fix Container Security
fix_container_security() {
  echo "Fixing Container Security..."
  
  # Create directory for task definitions
  mkdir -p security_fixes/task_definitions
  
  # Update task definition to add security measures
  jq '.containerDefinitions[0] += {
    "readonlyRootFilesystem": true,
    "privileged": false, 
    "user": "1000:1000",
    "linuxParameters": {
      "capabilities": {
        "drop": ["ALL"],
        "add": ["NET_BIND_SERVICE"]
      }
    }
  }' api-gateway-task-definition.json > security_fixes/task_definitions/api-gateway-task-definition-secure.json
  
  echo "Generated hardened task definition in security_fixes/task_definitions/"
}

# 4. Fix Security Group Rules
fix_security_groups() {
  echo "Fixing Security Group Rules..."
  
  # Create improved security group configuration
  cat > security_fixes/modules/security_groups_improved.tf << EOF
# Improved Security Group Configuration with least privilege

# Security group for API Gateway
resource "aws_security_group" "api_gateway" {
  name        = "\${var.environment}-api-gateway-sg"
  description = "Security group for API Gateway"
  vpc_id      = var.vpc_id
  
  # Allow HTTPS traffic only
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }
  
  # Specific egress rules instead of allowing all traffic
  egress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
    description     = "Allow traffic to ECS services"
  }
  
  tags = {
    Name = "\${var.environment}-api-gateway-sg"
  }
}

# Security group for ECS services
resource "aws_security_group" "ecs" {
  name        = "\${var.environment}-ecs-sg"
  description = "Security group for ECS services"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port       = 8081
    to_port         = 8082
    protocol        = "tcp"
    security_groups = [aws_security_group.api_gateway.id]
    description     = "Allow traffic from API Gateway"
  }
  
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self            = true
    description     = "Allow all traffic from self"
  }
  
  # Specific egress rules for each service
  egress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.mysql.id]
    description     = "Allow MySQL traffic"
  }
  
  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.postgres.id]
    description     = "Allow PostgreSQL traffic"
  }
  
  egress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.redis.id]
    description     = "Allow Redis traffic"
  }
  
  # Allow outbound HTTPS for external connections
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic for external connections"
  }
  
  tags = {
    Name = "\${var.environment}-ecs-sg"
  }
}
EOF
  
  echo "Generated improved security group configuration in security_fixes/modules/security_groups_improved.tf"
}

# 5. Create WAF Enhancements
enhance_waf() {
  echo "Enhancing WAF Configuration..."
  
  # Create improved WAF configuration
  cat > security_fixes/modules/waf_enhanced.tf << EOF
# Enhanced WAF Configuration

# Update the WAF Web ACL with additional security rules
resource "aws_wafv2_web_acl" "main" {
  # ... existing configuration ...
  
  # Add Geo-Restriction Rule
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
  
  # Add Bad Bot Control
  rule {
    name     = "BadBotRule"
    priority = 5
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BadBotRule"
      sampled_requests_enabled   = true
    }
  }
  
  # Add Known Bad Inputs Rule
  rule {
    name     = "KnownBadInputsRule"
    priority = 6
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsRule"
      sampled_requests_enabled   = true
    }
  }
}

# Enable WAF Logging
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
  
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
  
  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}
EOF
  
  echo "Generated enhanced WAF configuration in security_fixes/modules/waf_enhanced.tf"
}

# 6. Create Secrets Manager configuration
setup_secrets_manager() {
  echo "Setting up AWS Secrets Manager..."
  
  # Create secrets manager configuration
  cat > security_fixes/secrets_manager.tf << EOF
# AWS Secrets Manager Resources

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "\${var.environment}-internet-banking-db-credentials"
  description             = "Database credentials for Internet Banking application"
  recovery_window_in_days = 7
  
  tags = {
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    mysql_username    = var.mysql_username
    mysql_password    = var.mysql_password
    postgres_username = var.postgres_username
    postgres_password = var.postgres_password
    mysql_host        = module.internet_banking.mysql_endpoint
    postgres_host     = module.internet_banking.postgres_endpoint
    redis_host        = module.internet_banking.redis_endpoint
  })
}

# IAM policy for ECS tasks to access secrets
resource "aws_iam_policy" "secrets_access" {
  name        = "\${var.environment}-ecs-secrets-access"
  description = "Allows ECS tasks to access secrets in Secrets Manager"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn
        ]
      }
    ]
  })
}

# Attach policy to ECS task execution role
resource "aws_iam_role_policy_attachment" "secrets_access" {
  role       = module.internet_banking.ecs_task_execution_role_name
  policy_arn = aws_iam_policy.secrets_access.arn
}
EOF
  
  echo "Generated Secrets Manager configuration in security_fixes/secrets_manager.tf"
}

# Run all fix functions
fix_cloudwatch_encryption
fix_api_gateway_auth
fix_container_security
fix_security_groups
enhance_waf
setup_secrets_manager

echo "===== Security fixes generated ====="
echo "All security fixes have been generated in the 'security_fixes' directory."
echo "Review the changes and apply them to your infrastructure code."
echo
echo "Next steps:"
echo "1. Review all generated fixes in the 'security_fixes' directory"
echo "2. Apply the fixes to your terraform code"
echo "3. Run 'terraform plan' to validate changes"
echo "4. Apply the changes with 'terraform apply'"
echo "5. Update task definitions in ECS"
echo
echo "For a complete security and compliance plan, refer to security_compliance_plan.md" 