#!/bin/bash

# Security Scanning Script for Terraform Infrastructure
# This script runs security scans using checkov and tfsec

echo "Starting infrastructure security scans..."

# Create reports directory if it doesn't exist
mkdir -p security-reports

# Run Checkov scan
echo "Running Checkov scan on Terraform code..."
checkov -d . --framework terraform --output json > security-reports/terraform-checkov-report.json
checkov -d . --framework terraform --output cli

# Run tfsec scan
echo "Running tfsec scan on Terraform code..."
tfsec . --format json > security-reports/terraform-tfsec-report.json
tfsec .

echo "Security scans completed. Reports saved to security-reports/ directory."
