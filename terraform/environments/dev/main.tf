terraform {
  backend "s3" {
    bucket         = "internet-banking-terraform-state-dev"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-dev"
  }
}

module "internet_banking" {
  source = "../../"
  
  environment = "dev"
  aws_region  = "us-east-1"
  
  # VPC Configuration
  vpc_cidr            = "10.0.0.0/16"
  availability_zones  = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24"]
  
  # Database Configuration
  mysql_db_name     = "banking_core"
  mysql_username    = "admin"
  mysql_password    = "DevPassword123!" # In production, use AWS Secrets Manager
  postgres_db_name  = "keycloak"
  postgres_username = "keycloak"
  postgres_password = "DevPassword123!" # In production, use AWS Secrets Manager
  
  # Domain Configuration
  domain_name = "dev-internetbanking-example.com"
  certificate_arn = null
  
  # WAF Configuration
  waf_allowed_countries = ["US", "CA", "GB"]
  
  # Cross-Region Backup Configuration
  enable_cross_region_backup = false
  backup_kms_key_id = null
  backup_sns_topic_arn = null
  
  # CodePipeline Configuration
  aws_account_id = "156041437006"
  codestar_connection_arn = "arn:aws:codestar-connections:us-east-1:156041437006:connection/063c7eb0-7e04-4882-9a5a-810294a094cc"
  repository_id = "JavatoDev-com/internet-banking-concept-microservices"
  branch_name = "main"
}
