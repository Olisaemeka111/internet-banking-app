#!/bin/bash

# AWS Pipeline Security Verification Script
# This script verifies security settings for AWS CodeBuild and CodePipeline resources

set -e

echo "Starting AWS pipeline security verification..."

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is required but not installed."
    exit 1
fi

# Get account ID for resource validation
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

if [ -z "$AWS_ACCOUNT_ID" ] || [ -z "$AWS_REGION" ]; then
    echo "Error: Unable to determine AWS account ID or region."
    exit 1
fi

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"

# Check CodeBuild project encryption settings
check_codebuild_encryption() {
    local project_name=$1
    echo "Checking encryption settings for CodeBuild project: $project_name"

    local encryption_info=$(aws codebuild batch-get-projects --names "$project_name" --query "projects[0].encryptionKey" --output text)

    if [ "$encryption_info" == "None" ] || [ -z "$encryption_info" ]; then
        echo "❌ CodeBuild project '$project_name' is not using KMS encryption."
        return 1
    else
        echo "✅ CodeBuild project '$project_name' is using KMS encryption: $encryption_info"
        return 0
    fi
}

# Check CodeBuild project privilege mode
check_codebuild_privileged_mode() {
    local project_name=$1
    echo "Checking privileged mode for CodeBuild project: $project_name"

    local privileged_mode=$(aws codebuild batch-get-projects --names "$project_name" --query "projects[0].environment.privilegedMode" --output text)

    if [ "$privileged_mode" == "true" ]; then
        echo "⚠️ CodeBuild project '$project_name' is running in privileged mode. This is required for Docker builds but increases security risk."
        return 0
    else
        echo "✅ CodeBuild project '$project_name' is not running in privileged mode."
        return 0
    fi
}

# Check CodeBuild project IAM role permissions
check_codebuild_iam_role() {
    local project_name=$1
    echo "Checking IAM role for CodeBuild project: $project_name"

    local role_arn=$(aws codebuild batch-get-projects --names "$project_name" --query "projects[0].serviceRole" --output text)

    if [ "$role_arn" == "None" ] || [ -z "$role_arn" ]; then
        echo "❌ Unable to determine IAM role for CodeBuild project '$project_name'."
        return 1
    fi

    local role_name=$(echo "$role_arn" | cut -d '/' -f 2)
    echo "Role: $role_name"

    # Check if role has admin permissions
    local admin_policy=$(aws iam list-attached-role-policies --role-name "$role_name" --query "AttachedPolicies[?PolicyName=='AdministratorAccess'].PolicyName" --output text)

    if [ -n "$admin_policy" ]; then
        echo "❌ CodeBuild role '$role_name' has administrator permissions. This violates least privilege principle."
        return 1
    else
        echo "✅ CodeBuild role '$role_name' does not have administrator permissions."
        return 0
    fi
}

# Check CodePipeline artifact encryption
check_pipeline_encryption() {
    local pipeline_name=$1
    echo "Checking encryption settings for CodePipeline: $pipeline_name"

    local encryption_key=$(aws codepipeline get-pipeline --name "$pipeline_name" --query "pipeline.artifactStore.encryptionKey.id" --output text 2>/dev/null)

    if [ "$encryption_key" == "None" ] || [ -z "$encryption_key" ]; then
        echo "❌ CodePipeline '$pipeline_name' is not using KMS encryption for artifacts."
        return 1
    else
        echo "✅ CodePipeline '$pipeline_name' is using KMS encryption: $encryption_key"
        return 0
    fi
}

# Check S3 bucket encryption for pipeline artifacts
check_s3_artifact_encryption() {
    local pipeline_name=$1
    echo "Checking S3 artifact bucket encryption for pipeline: $pipeline_name"

    local bucket_name=$(aws codepipeline get-pipeline --name "$pipeline_name" --query "pipeline.artifactStore.location" --output text 2>/dev/null)

    if [ -z "$bucket_name" ]; then
        echo "❌ Unable to determine artifact bucket for pipeline '$pipeline_name'."
        return 1
    fi

    local encryption_config=$(aws s3api get-bucket-encryption --bucket "$bucket_name" 2>/dev/null)
    local exit_status=$?

    if [ $exit_status -ne 0 ]; then
        echo "❌ S3 bucket '$bucket_name' does not have encryption configured."
        return 1
    else
        echo "✅ S3 bucket '$bucket_name' has encryption configured."
        return 0
    fi
}

# Verify project security
verify_project_security() {
    local codebuild_project=$1
    local pipeline_name=$2

    echo "\n=== Verifying security for project '$codebuild_project' ==="

    local build_encryption_ok=0
    local build_privileged_ok=0
    local build_iam_ok=0
    local pipeline_encryption_ok=0
    local s3_encryption_ok=0

    check_codebuild_encryption "$codebuild_project" || build_encryption_ok=1
    check_codebuild_privileged_mode "$codebuild_project" || build_privileged_ok=1
    check_codebuild_iam_role "$codebuild_project" || build_iam_ok=1

    if [ -n "$pipeline_name" ]; then
        check_pipeline_encryption "$pipeline_name" || pipeline_encryption_ok=1
        check_s3_artifact_encryption "$pipeline_name" || s3_encryption_ok=1
    fi

    local total_issues=$((build_encryption_ok + build_privileged_ok + build_iam_ok + pipeline_encryption_ok + s3_encryption_ok))

    if [ "$total_issues" -eq 0 ]; then
        echo "\n✅ All security checks passed for project '$codebuild_project'."
    else
        echo "\n⚠️ Found $total_issues security issues for project '$codebuild_project'."
    fi

    return $total_issues
}

# Main function to verify pipeline security
main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <codebuild_project_name> [pipeline_name]"
        exit 1
    fi

    local codebuild_project=$1
    local pipeline_name=$2

    verify_project_security "$codebuild_project" "$pipeline_name"
    exit_status=$?

    echo "\nSecurity verification completed with status: $exit_status"
    exit $exit_status
}

# Run the script with provided arguments
main "$@"
