# Secrets Management

This directory contains secret files used by the docker-compose configuration. In a production environment, these secrets should be managed by a dedicated secrets management solution like HashiCorp Vault or AWS Secrets Manager.

## Secret Files Required

Create the following files in this directory with appropriate secure values:

- `mysql_root_password.txt`: MySQL root password
- `postgres_user.txt`: PostgreSQL username
- `postgres_password.txt`: PostgreSQL password
- `keycloak_db_user.txt`: Keycloak database username
- `keycloak_db_password.txt`: Keycloak database password
- `keycloak_admin.txt`: Keycloak admin username
- `keycloak_admin_password.txt`: Keycloak admin password
- `user_service_db_password.txt`: User service database password
- `fund_service_db_password.txt`: Fund transfer service database password
- `utility_service_db_password.txt`: Utility payment service database password
- `core_service_db_password.txt`: Core banking service database password
- `encrypt_key.txt`: Encryption key for sensitive data

## Security Guidelines

1. Use strong, unique passwords (minimum 16 characters with a mix of uppercase, lowercase, numbers, and special characters)
2. Set appropriate file permissions: `chmod 400 *.txt`
3. Never commit these files to version control
4. Implement a secret rotation policy
5. In production, use a proper secrets management solution instead of files

## Example Secret Generation

```bash
# Generate a strong random password
openssl rand -base64 32 > mysql_root_password.txt

# Set proper permissions
chmod 400 mysql_root_password.txt
```

## Secret Rotation Policy

All secrets should be rotated every 90 days following these steps:

1. Generate new secrets
2. Update the secret files or secrets management solution
3. Restart the affected services
4. Verify all services are functioning correctly
