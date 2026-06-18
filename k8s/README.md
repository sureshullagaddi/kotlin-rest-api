# Kubernetes Manifests (Non-Helm)

This directory contains additional Kubernetes manifests that complement the Helm charts. These files define cluster-level policies, RBAC, and security standards.

## Directory Structure

```
k8s/
├── dev/
│   ├── namespace.yaml           # Development namespace
│   ├── network-policies.yaml    # Network isolation (dev)
│   └── rbac.yaml                # RBAC roles (dev)
│
└── prod/
    ├── namespace.yaml           # Production namespace
    ├── network-policies.yaml    # Network isolation (prod)
    ├── rbac.yaml                # RBAC roles (prod)
    └── pod-security-standards.yaml  # PodSecurityStandards
```

## Deployment Order

1. Create namespace: `kubectl apply -f k8s/{env}/namespace.yaml`
2. Apply RBAC: `kubectl apply -f k8s/{env}/rbac.yaml`
3. Apply network policies: `kubectl apply -f k8s/{env}/network-policies.yaml`
4. Deploy Helm chart: `helm install ...`

## Files Included

### namespace.yaml
Creates dedicated Kubernetes namespace with labels for segregation.

### rbac.yaml
- ServiceAccount
- Role (permissions)
- RoleBinding (attach role to service account)
- ClusterRole (if needed)
- ClusterRoleBinding

### network-policies.yaml
- Ingress policies (allow external traffic)
- Egress policies (allow outbound connections)
- Pod-to-pod communication rules
- DNS access

### pod-security-standards.yaml (Production Only)
Enforces Kubernetes Pod Security Standards to restrict privileged containers.

## Usage

### Development Environment
```bash
kubectl apply -f k8s/dev/
helm install fusion-api ./helm/api-chart -f helm/values-dev.yaml -n fusion-namespace
```

### Production Environment
```bash
kubectl apply -f k8s/prod/
helm install fusion-api ./helm/api-chart -f helm/values-prod.yaml -n fusion-namespace
```

## Network Policies

Example network policies restrict traffic:

**Ingress:**
- Allow from ALB/Ingress controller
- Allow from Prometheus scraper
- Deny all others (implicit default deny)

**Egress:**
- Allow to PostgreSQL database
- Allow to AWS APIs (for CloudWatch logging)
- Allow DNS (port 53)
- Deny all others

## RBAC Configuration

ServiceAccount is configured with minimal permissions:

- Get ConfigMaps (for reading configuration)
- Optional: Access to AWS IAM for CloudWatch permissions (via IRSA)

## References

- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

