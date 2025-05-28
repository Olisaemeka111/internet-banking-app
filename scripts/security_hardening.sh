#!/bin/bash

# Security Hardening Script for Internet Banking Application
# This script implements security best practices for the application

echo "Starting security hardening process..."

# Create directories if they don't exist
mkdir -p docker-compose/secrets
mkdir -p security-reports
mkdir -p security-templates

# Generate secure secrets for Docker Compose
generate_secret() {
    local file=$1
    local length=$2
    if [ ! -f "$file" ]; then
        echo "Generating secret: $file"
        openssl rand -base64 $length > "$file"
        chmod 400 "$file"
    else
        echo "Secret already exists: $file"
    fi
}

echo "Generating secure secrets..."
generate_secret "docker-compose/secrets/mysql_root_password.txt" 32
generate_secret "docker-compose/secrets/postgres_user.txt" 16
generate_secret "docker-compose/secrets/postgres_password.txt" 32
generate_secret "docker-compose/secrets/keycloak_db_user.txt" 16
generate_secret "docker-compose/secrets/keycloak_db_password.txt" 32
generate_secret "docker-compose/secrets/keycloak_admin.txt" 16
generate_secret "docker-compose/secrets/keycloak_admin_password.txt" 32
generate_secret "docker-compose/secrets/user_service_db_password.txt" 32
generate_secret "docker-compose/secrets/fund_service_db_password.txt" 32
generate_secret "docker-compose/secrets/utility_service_db_password.txt" 32
generate_secret "docker-compose/secrets/core_service_db_password.txt" 32
generate_secret "docker-compose/secrets/encrypt_key.txt" 32

# Run security scans
echo "Running security scans..."

# Create enhanced security scan script
cat > security-scan-enhanced.sh << 'EOF'
#!/bin/bash

# Enhanced Security Scanning Script for Internet Banking App

echo "Starting comprehensive security scans..."

# Create reports directory if it doesn't exist
mkdir -p security-reports

# Current date for reports
DATE=$(date +"%Y-%m-%d")

# Run Checkov scan
echo "Running Checkov scan..."
checkov -d . --quiet --framework all --skip-path '.git,.gradle' --output json > security-reports/checkov-report-$DATE.json
checkov -d . --quiet --framework all --skip-path '.git,.gradle' --output cli

# Check if Terraform files exist
TF_FILES=$(find . -name "*.tf" | wc -l)
if [ "$TF_FILES" -gt 0 ]; then
  # Run tfsec scan
  echo "Running tfsec scan on Terraform files..."
  if command -v tfsec &> /dev/null; then
    tfsec . --format json > security-reports/tfsec-report-$DATE.json
    tfsec .
  else
    echo "tfsec not found. Installing tfsec..."
    curl -sSL https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
    tfsec . --format json > security-reports/tfsec-report-$DATE.json
    tfsec .
  fi
else
  echo "No Terraform files found. Skipping tfsec scan."
fi

# Run OWASP Dependency Check if Java files exist
JAVA_FILES=$(find . -name "*.java" | wc -l)
if [ "$JAVA_FILES" -gt 0 ]; then
  echo "Running OWASP Dependency Check..."
  if command -v dependency-check &> /dev/null; then
    dependency-check --scan . --out security-reports/dependency-check-report-$DATE.html --format HTML
  else
    echo "OWASP Dependency Check not found. Please install it manually."
  fi
else
  echo "No Java files found. Skipping OWASP Dependency Check."
fi

# Run Docker image scanning
if command -v trivy &> /dev/null; then
  echo "Running Trivy container security scans..."
  # Get all local Docker images
  for img in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>"); do
    echo "Scanning image: $img"
    trivy image --severity HIGH,CRITICAL --format json -o security-reports/trivy-$img-$DATE.json $img
  done
else
  echo "Trivy not found. Skipping container scanning."
fi

# Scan for secrets in code
if command -v gitleaks &> /dev/null; then
  echo "Running Gitleaks to find secrets in code..."
  gitleaks detect --source . -v --report-format json --report-path security-reports/gitleaks-report-$DATE.json
else
  echo "Gitleaks not found. Skipping secrets scanning."
fi

echo "Security scans completed. Reports saved to security-reports/ directory."
EOF

chmod +x security-scan-enhanced.sh

# Create .gitignore for security files
cat >> .gitignore << EOF
# Security-related files
docker-compose/secrets/
security-reports/
*.key
*.pem
*.crt
*.p12
*.jks
EOF

# Create security-templates directory with secure configuration templates
mkdir -p security-templates

# Create security policy
cat > security-templates/security-policy.md << EOF
# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability within this project, please send an email to security@example.com. All security vulnerabilities will be promptly addressed.

## Security Practices

1. **Access Control**: Principle of least privilege is applied to all components.
2. **Secrets Management**: All secrets are stored securely and rotated regularly.
3. **Encryption**: All sensitive data is encrypted at rest and in transit.
4. **Authentication**: Strong authentication mechanisms are used throughout the application.
5. **Logging and Monitoring**: Security events are logged and monitored.
6. **Regular Scanning**: Security scans are performed regularly on code and infrastructure.
7. **Patch Management**: All components are kept up-to-date with security patches.

## Security Standards

This project aims to comply with the following security standards:
- PCI DSS
- GDPR
- NIST Cybersecurity Framework
EOF

echo "Security hardening completed."
