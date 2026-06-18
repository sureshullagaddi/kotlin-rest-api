# Product Service - Cloud-Native REST API

A production-ready Kotlin/Spring Boot REST API application designed for AWS EKS deployment with PostgreSQL backend. Includes automated CI/CD pipelines, infrastructure-as-code, and Kubernetes orchestration.

---

## 🚀 Quick Start (5 minutes)

### Prerequisites
```bash
# Install required tools
brew install aws-cli kubectl helm terraform docker

# Verify installations
aws --version
kubectl version --client
helm version
terraform version
docker --version
```

### Local Development Setup

```bash
# 1. Clone and navigate
cd /path/to/product-service

# 2. Configure AWS credentials
aws configure
# Use: Account ID: 397979615352, Region: eu-north-1

# 3. Build the application
./gradlew clean build

# 4. Start local stack (PostgreSQL + API)
docker-compose up

# 5. Test endpoints
curl http://localhost:8080/actuator/health
curl http://localhost:8080/api/products
```

**Done!** API running at http://localhost:8080

---

## 📋 First-Time Setup Guide

### Step 1: Prerequisites (15 minutes)

**Install Tools:**
```bash
brew install aws-cli kubectl helm terraform docker

# Verify Java 17 (should be included with earlier installs)
java -version  # Should show version 17+
```

**Configure AWS:**
```bash
aws configure
# Access Key ID: [get from AWS console]
# Secret Access Key: [get from AWS console]
# Default region: eu-north-1
# Default output: json

# Verify
aws sts get-caller-identity
```

### Step 2: GitHub Setup (20 minutes)

**Create GitHub OIDC Role:**

```bash
# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com

# Create trust policy (save as trust-policy.json)
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::397979615352:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:sureshullagaddi/product-service:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name github-actions-oidc-role \
  --assume-role-policy-document file://trust-policy.json

# Attach admin policy (for testing; use least privilege in production)
aws iam attach-role-policy \
  --role-name github-actions-oidc-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

**Add GitHub Secrets:**

1. Go to GitHub Repository → Settings → Secrets and variables → Actions
2. Click "New repository secret" and add:

| Secret Name | Value |
|------------|-------|
| `AWS_ACCOUNT_ID` | 397979615352 |
| `AWS_REGION` | eu-north-1 |
| `DB_USERNAME` | postgres |
| `DB_PASSWORD` | YourSecurePassword123! |

### Step 3: Local Testing (10 minutes)

```bash
# Build
./gradlew clean build

# Run with Docker Compose
docker-compose up

# In another terminal, test CRUD operations:
# List products
curl http://localhost:8080/api/products

# Create product
curl -X POST http://localhost:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","price":999.99}'

# Get by ID
curl http://localhost:8080/api/products/1

# Update
curl -X PUT http://localhost:8080/api/products/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Gaming Laptop","price":1299.99}'

# Delete
curl -X DELETE http://localhost:8080/api/products/1

# Stop local stack
docker-compose down
```

---

## 🌐 Deployment Guide

### Deploy to Development

**Option 1: Automatic (via Git Push)**
```bash
git add .
git commit -m "Add new features"
git push origin develop
# GitHub Actions automatically deploys to dev
```

**Option 2: Manual Trigger**
1. Go to GitHub Actions → "Build & Deploy Product Service"
2. Click "Run workflow"
3. Select environment: `dev`
4. Click "Run workflow"
5. Wait ~20 minutes for deployment to complete

### Deploy to Production

**Same as Development, but:**
- Push to `main` branch (or select `prod` in manual trigger)
- Requires environment approval (configure in GitHub)
- Higher resource allocation (t3.large nodes, Multi-AZ RDS)

### Monitor Deployment

```bash
# Watch workflow in GitHub Actions
# Or use kubectl after deployment:

aws eks update-kubeconfig --region eu-north-1 --name product-service-eks-dev

kubectl get pods -n product-service -w
kubectl logs -n product-service -l app=product-service -f
```

---

## ✅ Post-Deployment Testing

### 1. Verify Pods Are Running

```bash
# Connect to cluster
aws eks update-kubeconfig --region eu-north-1 --name product-service-eks-dev

# Check pods
kubectl get pods -n product-service
# All should show "Running" status

# View pod details
kubectl describe pod <pod-name> -n product-service
```

### 2. Test Health Endpoints

```bash
# Port forward to service
kubectl port-forward -n product-service svc/product-service 8080:80 &

# Test health checks
curl http://localhost:8080/actuator/health
# Expected: {"status":"UP"}

curl http://localhost:8080/actuator/health/liveness
# Expected: {"status":"UP"}

curl http://localhost:8080/actuator/health/readiness
# Expected: {"status":"UP"}

# Kill port forward
kill %1
```

### 3. Test API Endpoints

```bash
# Assuming you have port-forward running from above

# List products (empty initially)
curl http://localhost:8080/api/products

# Create product
curl -X POST http://localhost:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Product",
    "price": 99.99
  }'

# Get all products
curl http://localhost:8080/api/products

# Get by ID
curl http://localhost:8080/api/products/1

# Update product
curl -X PUT http://localhost:8080/api/products/1 \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Product",
    "price": 149.99
  }'

# Delete product
curl -X DELETE http://localhost:8080/api/products/1

# Verify deletion
curl http://localhost:8080/api/products
```

### 4. Test Database Connectivity

```bash
# Get RDS endpoint
aws rds describe-db-instances \
  --region eu-north-1 \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text

# Connect and query (replace <endpoint> with actual endpoint)
psql -h <endpoint> -U postgres -d product_service

# Inside psql:
\d products          # Show table structure
SELECT * FROM products;  # View all products
\q                   # Quit
```

### 5. Check Logs

```bash
# Stream pod logs
kubectl logs -n product-service -l app=product-service -f

# Check for errors
kubectl logs -n product-service -l app=product-service | grep ERROR

# View previous logs (if pod restarted)
kubectl logs -n product-service <pod-name> --previous
```

### 6. Monitor Resource Usage

```bash
# CPU and memory usage
kubectl top pods -n product-service
kubectl top nodes

# Check pod events
kubectl describe pod <pod-name> -n product-service
```

### 7. Verify Auto-Scaling

```bash
# Check current replicas
kubectl get deployment -n product-service

# Scale manually (to test)
kubectl scale deployment/product-service --replicas=3 -n product-service

# Watch scaling
kubectl get deployment -n product-service -w

# Scale back
kubectl scale deployment/product-service --replicas=2 -n product-service
```

### 8. Test Production Ingress (Prod Only)

```bash
# Check ingress
kubectl get ingress -n product-service

# Get ALB endpoint
kubectl describe ingress -n product-service | grep "Address"

# Test via HTTPS
curl -v https://api.productservice.com/actuator/health
# (May need to update DNS/hosts file for local testing)
```

---

## 🧹 Cleanup

### Destroy Development Environment

```bash
# Via GitHub Actions:
# 1. Actions → "Destroy Infrastructure & Resources"
# 2. Run workflow
# 3. Select environment: dev
# 4. Enter confirmation: DESTROY (type exactly)
# 5. Wait 30-40 minutes for complete cleanup

# OR via CLI:
cd terraform/dev
terraform plan -destroy
terraform destroy

# Remove local kubeconfig entry
kubectl config delete-context product-service-eks-dev
```

### Cleanup Local Docker

```bash
docker-compose down
docker system prune -a
```

---

## 🏗️ Project Structure

```
product-service/
├── src/main/kotlin/com/rest/api/
│   ├── controller/              # REST endpoints
│   ├── service/                 # Business logic
│   ├── repository/              # Data access
│   ├── entity/                  # JPA entities
│   ├── config/                  # Spring configuration
│   └── exception/               # Error handling
├── src/main/resources/
│   ├── application.yml          # Dev config (H2)
│   ├── application-prod.yml     # Prod config (PostgreSQL)
│   ├── logback-spring.xml       # Logging
│   └── db/migration/            # Flyway migrations
├── helm/api-chart/              # Kubernetes Helm chart
│   ├── values.yaml              # Base values
│   ├── values-dev.yaml          # Dev overrides
│   ├── values-prod.yaml         # Prod overrides
│   └── templates/               # K8s manifests
├── terraform/
│   ├── dev/                     # Dev infrastructure
│   ├── prod/                    # Prod infrastructure
│   └── modules/                 # Shared TF modules
├── .github/workflows/
│   ├── deploy.yml               # Build & Deploy pipeline
│   └── destroy.yml              # Resource cleanup
├── docker-compose.yml           # Local dev stack
├── Dockerfile                   # Multi-stage Docker build
└── build.gradle.kts             # Gradle dependency management
```

---

## 🔧 Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Language | Kotlin | 1.9.0 |
| Framework | Spring Boot | 3.1.0 |
| Build Tool | Gradle | 8.x |
| Database | PostgreSQL | 16 |
| Migrations | Flyway | 9.22.3 |
| Container | Docker | 20.x |
| Orchestration | Kubernetes (EKS) | 1.27+ |
| IaC | Terraform | 1.5.0+ |
| Package Manager | Helm | 3.x |
| CI/CD | GitHub Actions | - |
| Cloud Provider | AWS | - |

---

## 📊 Cost Estimates

**Monthly Running Costs (eu-north-1):**

| Environment | Cost | Save by Destroying |
|-------------|------|-------------------|
| Dev | ~$150 | $45/month if nightly |
| Prod | ~$550 | $165/month if weekends |
| **Total** | **~$700** | **~$210/month optimized** |

---

## 🚨 Common Issues & Fixes

### Pod Won't Start

```bash
# Check events
kubectl describe pod <pod-name> -n product-service

# Check logs
kubectl logs <pod-name> -n product-service

# Common fixes:
# - Increase resource limits (memory/CPU)
# - Wait for cluster to stabilize after creation
# - Check database connectivity
```

### Database Connection Fails

```bash
# Verify RDS is running
aws rds describe-db-instances --region eu-north-1

# Check security group allows traffic
aws ec2 describe-security-groups --region eu-north-1

# Test from pod
kubectl exec -it <pod> -n product-service -- \
  psql -h <endpoint> -U postgres -d product_service
```

### Workflow Fails

```bash
# Check GitHub Actions logs for detailed error
# Common causes:
# 1. Missing secrets: Verify all 4 secrets in GitHub
# 2. AWS credentials: Check OIDC role and trust policy
# 3. Image push failed: Check ECR repository exists
```

### High Costs

```bash
# Solutions:
# 1. Destroy dev when not using (saves $45/month)
# 2. Destroy prod on weekends (saves $165/month)
# 3. Use reserved instances (saves 40% on RDS)
# 4. Use spot instances for non-critical nodes (saves 70%)
```

---

## 📚 Additional Resources

- **AWS EKS**: https://docs.aws.amazon.com/eks/
- **Kubernetes**: https://kubernetes.io/docs/
- **Helm**: https://helm.sh/docs/
- **Terraform AWS**: https://registry.terraform.io/providers/hashicorp/aws/
- **Spring Boot**: https://spring.io/projects/spring-boot
- **PostgreSQL**: https://www.postgresql.org/docs/

---

## 📝 Summary

1. **Local Development**: Use `docker-compose up` for local PostgreSQL + API
2. **Deploy Dev**: Push to `develop` branch (automatic via GitHub Actions)
3. **Deploy Prod**: Push to `main` branch (automatic via GitHub Actions)
4. **Test** After Deployment: Use curl commands provided to verify API responses
5. **Monitor**: Check logs and pod status with kubectl
6. **Cleanup**: Use destroy workflow for complete resource cleanup

**Status**: ✅ Ready for Production Deployment
