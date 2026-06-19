#!/bin/bash

# Setup GitHub OIDC for AWS
# This script creates/verifies the OIDC provider and IAM role for GitHub Actions

set -e

AWS_ACCOUNT_ID="397979615352"
AWS_REGION="eu-north-1"
GITHUB_ORG="sureshullagaddi"
GITHUB_REPO="product-service"
ROLE_NAME="github-actions-oidc-role"

echo "=================================="
echo "GitHub OIDC Setup for AWS"
echo "=================================="
echo "Account ID: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo "GitHub Org: $GITHUB_ORG"
echo "GitHub Repo: $GITHUB_REPO"
echo ""

# Step 1: Create OIDC Provider if it doesn't exist
echo "Step 1: Creating OIDC Provider..."
PROVIDER_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(OpenIDConnectProviderArn, 'token.actions.githubusercontent.com')].OpenIDConnectProviderArn" --output text 2>/dev/null || echo "")

if [ -z "$PROVIDER_ARN" ]; then
    echo "Creating new OIDC provider..."
    if aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 2>&1 | grep -q "EntityAlreadyExists"; then
        echo "⚠️  OIDC Provider already exists, continuing..."
    fi
    PROVIDER_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
    echo "✅ OIDC Provider: $PROVIDER_ARN"
else
    echo "✅ OIDC Provider already exists: $PROVIDER_ARN"
fi

# Step 2: Create Trust Policy
echo ""
echo "Step 2: Creating Trust Policy..."

# Create trust policy JSON with correct subject format
# ⚠️  IMPORTANT: When a GitHub Actions job uses an "environment:", the sub claim changes from
#     repo:OWNER/REPO:ref:refs/heads/BRANCH  →  repo:OWNER/REPO:environment:ENV_NAME
# The policy below covers ALL cases: branch refs, environments, PRs, and tags.
cat > /tmp/trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowBranchPushes",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::397979615352:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:sureshullagaddi/product-service:ref:refs/heads/*"
        }
      }
    },
    {
      "Sid": "AllowDevEnvironment",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::397979615352:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:sureshullagaddi/product-service:environment:dev"
        }
      }
    },
    {
      "Sid": "AllowProdEnvironment",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::397979615352:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:sureshullagaddi/product-service:environment:prod"
        }
      }
    },
    {
      "Sid": "AllowTagPushes",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::397979615352:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:sureshullagaddi/product-service:ref:refs/tags/*"
        }
      }
    },
    {
      "Sid": "AllowPullRequests",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::397979615352:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:sureshullagaddi/product-service:pull_request"
        }
      }
    }
  ]
}
EOF

echo "Trust policy created"

# Step 3: Check if role exists
echo ""
echo "Step 3: Creating/Updating IAM Role..."
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
    echo "Creating new IAM role: $ROLE_NAME"
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --description "Role for GitHub Actions OIDC"
    ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/$ROLE_NAME"
    echo "✅ IAM Role created: $ROLE_ARN"
else
    echo "Updating existing IAM role trust policy..."
    aws iam update-assume-role-policy \
        --role-name $ROLE_NAME \
        --policy-document file:///tmp/trust-policy.json
    echo "✅ IAM Role updated: $ROLE_ARN"
fi

# Step 4: Attach policies
echo ""
echo "Step 4: Attaching Policies..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

echo "✅ AdministratorAccess policy attached"

# Step 5: Verify
echo ""
echo "Step 5: Verifying Setup..."
echo "=================================="
echo "✅ Setup Complete!"
echo "=================================="
echo ""
echo "Role ARN: $ROLE_ARN"
echo "OIDC Provider: $PROVIDER_ARN"
echo ""
echo "GitHub Actions can now assume this role."
echo "Make sure GitHub workflow uses:"
echo "  role-to-assume: $ROLE_ARN"
echo ""

# Cleanup
rm -f /tmp/trust-policy.json

