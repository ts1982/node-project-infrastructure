#!/bin/bash

# State Integrity Check Script
# Detects and prevents state drift issues

set -e

TERRAFORM_DIR="terraform/envs/stg"
BACKUP_DIR="backups/state"

echo "🔍 State Integrity Check Starting..."

# 1. Check for errored.tfstate
if [ -f "$TERRAFORM_DIR/errored.tfstate" ]; then
    echo "⚠️  CRITICAL: errored.tfstate detected - state fork present"
    echo "📊 Comparing errored.tfstate vs remote state..."
    
    # Compare sizes
    ERRORED_SIZE=$(wc -c < "$TERRAFORM_DIR/errored.tfstate")
    REMOTE_SIZE=$(cd "$TERRAFORM_DIR" && terraform state pull | wc -c)
    
    echo "🔢 errored.tfstate: $ERRORED_SIZE bytes"
    echo "🔢 remote state: $REMOTE_SIZE bytes"
    
    if [ "$ERRORED_SIZE" -lt "$REMOTE_SIZE" ]; then
        echo "⚠️  errored.tfstate is smaller - likely partial destroy state"
        echo "🛑 Manual intervention required!"
        exit 1
    fi
fi

# 2. Check critical IAM policies
echo "🔐 Checking critical IAM policies..."
GITHUB_POLICY_COUNT=$(aws iam list-attached-role-policies --role-name studify-stg-github-actions-backend --query 'length(AttachedPolicies)' --output text)

if [ "$GITHUB_POLICY_COUNT" -eq 0 ]; then
    echo "❌ GitHub Actions IAM policy missing - will cause permission errors"
    echo "🔧 Auto-repair available: terraform apply -target=module.github_oidc.aws_iam_policy.github_actions_backend"
    exit 1
fi

# 3. Check state lock status
echo "🔒 Checking state lock status..."
cd "$TERRAFORM_DIR"
if ! terraform plan -detailed-exitcode >/dev/null 2>&1; then
    echo "⚠️  State lock detected or other issues present"
    terraform force-unlock -force $(aws dynamodb scan --table-name studify-terraform-locks --query 'Items[0].LockID.S' --output text) || true
fi

echo "✅ State integrity check passed"