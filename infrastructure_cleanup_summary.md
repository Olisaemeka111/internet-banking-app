# Internet Banking Infrastructure Cleanup Summary

## Resources Successfully Deleted

### ECS Resources
- ECS Cluster: `dev-internet-banking-cluster`
- ECS Services:
  - `dev-internet-banking-api-gateway`
  - `dev-internet-banking-service-registry`
  - `dev-internet-banking-config-server`
  - `dev-internet-banking-fund-transfer-service`
  - `dev-zipkin`
  - `dev-keycloak`
  - `dev-internet-banking-user-service`
  - `dev-core-banking-service`
  - `dev-internet-banking-utility-payment-service`

### Load Balancers
- Network Load Balancer: `dev-network-lb`
- Application Load Balancer (Public): `dev-public-alb`
- Application Load Balancer (Internal): `dev-internal-alb`

### Target Groups
- `dev-api-gateway-tg`
- `dev-config-server-tg`
- `dev-core-banking-service-tg`
- `dev-fund-transfer-service-tg`
- `dev-keycloak-tg`
- `dev-service-registry-tg`
- `dev-user-service-tg`
- `dev-utility-payment-service-tg`
- `dev-zipkin-tg`

### ECR Repositories
- `internet-banking-utility-payment-service`
- `internet-banking-config-server`
- `internet-banking-service-registry`
- `internet-banking-fund-transfer-service`
- `internet-banking-api-gateway`
- `internet-banking-user-service`

## Resources In Process of Being Deleted

### Database Resources
- RDS MySQL Instance: `dev-banking-core-mysql` (deletion in progress)
- RDS PostgreSQL Instance: `dev-keycloak-postgres` (deletion in progress)

### Cache Resources
- ElastiCache Redis Cluster: `dev-internet-banking-redis` (deletion in progress)

## Resources Pending Deletion

### Network Resources
- VPC: `vpc-0d57b94cbe8b4c11c`
- Security Groups:
  - `sg-013c73bd915cc108a` (dev-ecs-sg)
  - `sg-08dbe78a2356a6f89` (dev-postgres-sg)
  - `sg-0b1f171164c7c2bab` (dev-mysql-sg)
  - `sg-03141ff6b27d60e8a`
  - `sg-040fa78a60f956224` (default)

## Next Steps
1. Wait for the database and cache resources to complete deletion
2. Delete the security groups
3. Delete the subnets, route tables, internet gateways, and NAT gateways
4. Delete the VPC

## Note
The infrastructure was originally deployed using Terraform, but due to issues with the Terraform state, we had to manually delete the resources using the AWS CLI.
