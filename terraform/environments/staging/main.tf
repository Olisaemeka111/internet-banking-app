terraform {
  backend "s3" {
    bucket         = "internet-banking-terraform-state-staging"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-staging"
  }
}

module "internet_banking" {
  source = "../../"
  
  environment = "staging"
  aws_region  = "us-east-1"
  
  # VPC Configuration
  vpc_cidr            = "10.0.0.0/16"
  availability_zones  = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  
  # Database Configuration
  mysql_db_name     = "banking_core"
  mysql_username    = "admin"
  mysql_password    = "StagingPassword123!" # In production, use AWS Secrets Manager
  postgres_db_name  = "keycloak"
  postgres_username = "keycloak"
  postgres_password = "StagingPassword123!" # In production, use AWS Secrets Manager
  
  # Domain Configuration
  domain_name = "staging-internetbanking-example.com"
}
