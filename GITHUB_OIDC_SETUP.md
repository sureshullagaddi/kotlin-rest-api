# GitHub OIDC AWS Setup Guide

## Problem
GitHub Actions cannot assume the OIDC role because the trust policy repo name (`product-service`) does not match the actual GitHub repository name (`kotlin-rest-api`).

The OIDC `sub` claim is based on the **actual GitHub repository name** (from the git remote URL), not the local folder name. Since the git remote is `https://github.com/sureshullagaddi/kotlin-rest-api.git`, all `sub` claims will contain `kotlin-rest-api`.

## Solution

### Step 1: Run the Setup Script (RECOMMENDED)

```bash
cd /Users/suresh/Documents/kotlin-rest-api
chmod +x setup-github-oidc.sh
./setup-github-oidc.sh
```

**This script will:**
- ✅ Create the OIDC provider (if not exists)
- ✅ Create the IAM role with correct trust policy using `kotlin-rest-api`
- ✅ Attach the AdministratorAccess policy
- ✅ Verify everything works

---

## Step 2: Manual Setup (If Script Fails)

### 2a. Create OIDC Provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region eu-north-1
```

**Expected Output:**
```
{
  "OpenIDConnectProviderArn": "arn:aws:iam::397979615352:oidc-provider/token.actions.githubusercontent.com"
}
```

### 2b. Create Trust Policy File

> ⚠️ **Critical**: When a GitHub Actions job uses an `environment:` key, the OIDC `sub` claim
> changes from `repo:OWNER/REPO:ref:refs/heads/BRANCH` to `repo:OWNER/REPO:environment:ENV_NAME`.
> The trust policy **must** cover all claim formats your workflow uses.
>
> ⚠️ **The repo name in the sub claim must match the GitHub repository name exactly** — it is
> `kotlin-rest-api` (the git remote name), NOT the local folder name.

Save this as `trust-policy.json`:

```json
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
          "token.actions.githubusercontent.com:sub": "repo:sureshullagaddi/kotlin-rest-api:ref:refs/heads/*"
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
          "token.actions.githubusercontent.com:sub": "repo:sureshullagaddi/kotlin-rest-api:environment:dev"
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
          "token.actions.githubusercontent.com:sub": "repo:sureshullagaddi/kotlin-rest-api:environment:prod"
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
          "token.actions.githubusercontent.com:sub": "repo:sureshullagaddi/kotlin-rest-api:pull_request"
        }
      }
    }
  ]
}
```

### 2c. Create IAM Role

```bash
aws iam create-role \
  --role-name github-actions-oidc-role \
  --assume-role-policy-document file://trust-policy.json \
  --description "Role for GitHub Actions OIDC"
```

### 2d. Attach Admin Policy

```bash
aws iam attach-role-policy \
  --role-name github-actions-oidc-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

### 2e. Verify Role

```bash
aws iam get-role --role-name github-actions-oidc-role
```

---

## Step 3: Update GitHub Repository

1. Go to: **GitHub Repository → Settings → Environments**

2. Click **New environment** and create two:
   - **Environment 1**: `dev`
   - **Environment 2**: `prod`

3. For **Production** environment only (optional but recommended):
   - Add required reviewers
   - Set protection rules

---

## Step 4: Verify Workflow Updated

Check that `.github/workflows/deploy.yml` contains:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::${{ env.AWS_ACCOUNT_ID }}:role/github-actions-oidc-role
    aws-region: ${{ env.AWS_REGION }}
```

✅ Already updated!

---

## Step 5: Test the Setup

1. Push changes to `develop` branch:
```bash
git add .
git commit -m "Fix GitHub OIDC trust policy repo name"
git push origin develop
```

2. Go to **GitHub Actions** and watch the workflow

3. The "Configure AWS Credentials" step should now **succeed** with output like:
```
AWS credentials configured for arn:aws:iam::397979615352:role/github-actions-oidc-role
```

---

## Troubleshooting

### Root Cause: Trust Policy Repo Name Must Match the GitHub Remote

The **#1 cause** of `Not authorized to perform sts:AssumeRoleWithWebIdentity` is a mismatch between the repo name in the trust policy `sub` condition and the actual GitHub repository name.

The `sub` claim is built from the **git remote URL**, not the local folder name:
- Local folder: `kotlin-rest-api` (irrelevant)
- Git remote: `https://github.com/sureshullagaddi/kotlin-rest-api.git`
- Actual `sub` claim: `repo:sureshullagaddi/kotlin-rest-api:ref:refs/heads/develop`

If the trust policy says `product-service` but the repo is `kotlin-rest-api`, every attempt will fail.

### Root Cause: GitHub Environment vs Branch `sub` Claim Mismatch

GitHub's OIDC `sub` claim format depends on the **job context**:

| Job Context | `sub` claim format |
|---|---|
| Branch push (no environment) | `repo:OWNER/REPO:ref:refs/heads/BRANCH` |
| Job with `environment: dev` | `repo:OWNER/REPO:environment:dev` |
| Job with `environment: prod` | `repo:OWNER/REPO:environment:prod` |
| Pull request | `repo:OWNER/REPO:pull_request` |
| Tag push | `repo:OWNER/REPO:ref:refs/tags/TAG` |

If your workflow jobs use `environment:`, the trust policy **must** explicitly allow the `environment:dev`/`environment:prod` sub claims — `ref:refs/heads/*` wildcards will **not** match them.

---

### If Still Getting "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Check 1: Verify OIDC Provider Exists**
```bash
aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(OpenIDConnectProviderArn, 'token.actions.githubusercontent.com')].OpenIDConnectProviderArn"
```

Should return: `arn:aws:iam::397979615352:oidc-provider/token.actions.githubusercontent.com`

**Check 2: Verify Role Trust Policy**
```bash
aws iam get-role --role-name github-actions-oidc-role --query 'Role.AssumeRolePolicyDocument'
```

Should contain:
- `token.actions.githubusercontent.com` in Federated
- `sureshullagaddi/kotlin-rest-api` in sub
- `sts.amazonaws.com` in aud

**Check 3: Verify Role Permissions**
```bash
aws iam list-attached-role-policies --role-name github-actions-oidc-role
```

Should show `AdministratorAccess` attached

**Check 4: Verify GitHub Repo Name (matches git remote)**
```bash
git remote get-url origin
# Should print: https://github.com/sureshullagaddi/kotlin-rest-api.git
```

### If OIDC Provider Creation Fails

```bash
# Check if it already exists (may need to update)
aws iam list-open-id-connect-providers

# If it exists but with wrong config, delete and recreate:
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::397979615352:oidc-provider/token.actions.githubusercontent.com
```

---

## Reference Links

- [AWS OIDC Docs](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html)
- [GitHub OIDC in AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Configure AWS Credentials Action](https://github.com/aws-actions/configure-aws-credentials)

---

## Next Steps

Once OIDC is working:

1. ✅ Push to `develop` → Auto deploys to **dev**
2. ✅ Push to `main` → Auto deploys to **prod**
3. ✅ GitHub Actions can assume AWS role successfully
4. ✅ Terraform runs and provisions infrastructure
5. ✅ Helm deploys application to EKS

**Estimated time to get this working: 10-15 minutes** ⏱️
