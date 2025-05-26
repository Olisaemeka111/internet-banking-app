#!/bin/bash

# Security Scanning Script for Internet Banking App
# This script runs security scans using checkov and tfsec

echo "Starting security scans..."

# Create reports directory if it doesn't exist
mkdir -p security-reports

# Run Checkov scan
echo "Running Checkov scan..."
checkov -d . --quiet --framework all --skip-path '.git,.gradle' --output json > security-reports/checkov-report.json
checkov -d . --quiet --framework all --skip-path '.git,.gradle' --output cli

# Check if Terraform files exist
TF_FILES=$(find . -name "*.tf" | wc -l)
if [ "$TF_FILES" -gt 0 ]; then
  # Run tfsec scan
  echo "Running tfsec scan on Terraform files..."
  if command -v tfsec &> /dev/null; then
    tfsec . --format json > security-reports/tfsec-report.json
    tfsec .
  else
    echo "tfsec not found. Installing tfsec..."
    curl -sSL https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
    tfsec . --format json > security-reports/tfsec-report.json
    tfsec .
  fi
else
  echo "No Terraform files found. Skipping tfsec scan."
fi

echo "Security scans completed. Reports saved to security-reports/ directory."
