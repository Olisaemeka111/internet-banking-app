# Secure Docker Compose Setup

## Overview

This directory contains the Docker Compose configuration for running the Internet Banking Application securely in a containerized environment.

## Security Enhancements

The setup includes several security enhancements:

1. **Secrets Management**: All sensitive data (passwords, API keys) is stored using Docker secrets
2. **Network Isolation**: Services are isolated on a dedicated network
3. **Container Hardening**: Security options to prevent privilege escalation
4. **Health Checks**: Regular health monitoring of services
5. **Minimal Container Privileges**: Containers run with minimal privileges

## Setup Instructions

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+

### Initial Setup

1. First, set up the secrets directory:

```bash
# Create the secrets directory if it doesn't exist
mkdir -p secrets

# Generate secure secrets
./generate_secrets.sh
```

2. Start the services:

```bash
# Use the secure docker-compose file
docker-compose -f docker-compose-secure.yml up -d
```

### Security Best Practices

1. **Regular Updates**: Keep all container images updated with security patches
2. **Vulnerability Scanning**: Regularly scan containers for vulnerabilities using tools like Trivy
3. **Logging**: Enable and monitor container logs for suspicious activity
4. **Secret Rotation**: Rotate secrets regularly according to the security policy
5. **Access Control**: Restrict access to Docker daemon and the host system

## Container Security Configuration

Each container in the setup includes the following security configurations:

- `security_opt: ["no-new-privileges:true"]` - Prevents privilege escalation
- Health checks to monitor service status
- Non-root users for services where possible
- Read-only file systems where applicable
- Limited resource usage to prevent DoS attacks

## Monitoring

For enhanced security monitoring, consider integrating:

1. **Prometheus**: For container metrics monitoring
2. **Grafana**: For visualization of security metrics
3. **ELK Stack**: For centralized logging and analysis
4. **Wazuh**: For security event monitoring and alerting

## Troubleshooting

If you encounter issues with the secure setup:

1. Check the container logs: `docker-compose logs [service-name]`
2. Verify secrets are correctly mounted: `docker-compose exec [service-name] ls -la /run/secrets`
3. Validate network connectivity: `docker-compose exec [service-name] ping [other-service]`

## References

- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
