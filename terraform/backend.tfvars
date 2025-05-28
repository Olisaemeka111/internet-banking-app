bucket = "internet-banking-terraform-state-dev"
key    = "terraform.tfstate"
region = "us-east-1"
encrypt = true
dynamodb_table = "terraform-lock-dev"
