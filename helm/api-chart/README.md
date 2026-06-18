# Fusion API Helm Chart

Production-ready Helm chart for deploying the Fusion Hackathon REST API to Kubernetes.

## Prerequisites

- Kubernetes 1.20+
- Helm 3.0+
- kubectl configured with cluster access
- PostgreSQL database (RDS or self-hosted)
- Docker image in registry (ECR, Nexus, or Docker Hub)

## Chart Contents

```
api-chart/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default values (shared)
├── values-dev.yaml         # Development overrides
├── values-prod.yaml        # Production overrides
├── templates/
│   ├── deployment.yaml     # Pod deployment
│   ├── service.yaml        # Kubernetes service
│   ├── ingress.yaml        # Ingress routing
│   ├── configmap.yaml      # Configuration data
│   ├── hpa.yaml           # Auto-scaling
│   ├── pdb.yaml           # Pod disruption budget
│   ├── serviceaccount.yaml # RBAC service account
│   └── _helpers.tpl       # Template helpers
└── README.md              # This file
```

## Quick Start

### 1. Add Helm Repository (if using chart repo)

```bash
helm repo add fusion https://charts.fusion-hackathon.dev
helm repo update
```

### 2. Create Database Secrets

```bash
# Create Kubernetes secret with database credentials
kubectl create secret generic fusion-db-credentials \
  --from-literal=username=postgres \
  --from-literal=password=<YOUR_DB_PASSWORD> \
  -n fusion-namespace
```

### 3. Deploy to Development

```bash
helm install fusion-api ./api-chart \
  -f values-dev.yaml \
  -n fusion-namespace \
  --create-namespace
```

### 4. Deploy to Production

```bash
helm install fusion-api ./api-chart \
  -f values-prod.yaml \
  -n fusion-namespace \
  --create-namespace
```

## Configuration

### Environment-Specific Overrides

**Development:**
```bash
helm install fusion-api ./api-chart \
  --values values.yaml \
  --values values-dev.yaml \
  -n fusion-namespace
```

**Production:**
```bash
helm install fusion-api ./api-chart \
  --values values.yaml \
  --values values-prod.yaml \
  -n fusion-namespace
```

### Custom Values

Override any value from `values.yaml`:

```bash
helm install fusion-api ./api-chart \
  -f values-prod.yaml \
  --set replicaCount=5 \
  --set image.tag=v1.0.0 \
  --set ingress.hosts[0].host=api.mycompany.com \
  -n fusion-namespace
```

## Key Configuration Options

### Image

```yaml
image:
  repository: nexus.example.com/fusion-api/kotlin-rest-api
  tag: latest
  pullPolicy: IfNotPresent
```

### Replicas & Auto-Scaling

**Development (1 replica, no scaling):**
```yaml
replicaCount: 1
autoscaling:
  enabled: false
```

**Production (3+ replicas with HPA):**
```yaml
replicaCount: 3
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 60
```

### Database

```yaml
database:
  host: postgres.fusion-namespace.svc.cluster.local
  port: 5432
  name: fusion_api
  secretName: fusion-db-credentials
```

### Ingress

```yaml
ingress:
  enabled: true
  className: alb
  hosts:
    - host: api.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: fusion-api-tls
      hosts:
        - api.example.com
```

### Resources

```yaml
resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 500m
    memory: 1Gi
```

### Health Probes

```yaml
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 40
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 20
  periodSeconds: 5
```

## Deployment

### Install

```bash
helm install <release-name> ./api-chart -f values-prod.yaml -n <namespace>
```

### Upgrade

```bash
# Update image tag
helm upgrade fusion-api ./api-chart \
  -f values-prod.yaml \
  --set image.tag=v1.1.0 \
  -n fusion-namespace

# Full reconfiguration
helm upgrade fusion-api ./api-chart \
  -f values.yaml \
  -f values-prod.yaml \
  -n fusion-namespace
```

### Rollback

```bash
# Show revision history
helm history fusion-api -n fusion-namespace

# Rollback to previous version
helm rollback fusion-api -n fusion-namespace

# Rollback to specific revision
helm rollback fusion-api 2 -n fusion-namespace
```

### Uninstall

```bash
helm uninstall fusion-api -n fusion-namespace
```

## Validation

### Template Rendering

```bash
# View rendered manifests before deployment
helm template fusion-api ./api-chart -f values-prod.yaml
```

### Lint Chart

```bash
# Check chart for errors
helm lint ./api-chart
```

### Dry Run

```bash
# Simulate install without applying
helm install fusion-api ./api-chart \
  -f values-prod.yaml \
  --dry-run \
  --debug \
  -n fusion-namespace
```

## Troubleshooting

### Check Deployment Status

```bash
kubectl get deployments -n fusion-namespace
kubectl get pods -n fusion-namespace
kubectl get svc -n fusion-namespace
kubectl get ingress -n fusion-namespace
```

### View Pod Logs

```bash
kubectl logs -f deployment/fusion-api -n fusion-namespace
kubectl logs -f pod/<pod-name> -n fusion-namespace
```

### Describe Resources

```bash
kubectl describe deployment fusion-api -n fusion-namespace
kubectl describe pod <pod-name> -n fusion-namespace
kubectl describe ingress fusion-api -n fusion-namespace
```

### Check Events

```bash
kubectl get events -n fusion-namespace --sort-by='.lastTimestamp'
```

## Environment Variables

Available environment variables that can be customized:

| Variable | Default | Description |
|----------|---------|-------------|
| `SPRING_PROFILES_ACTIVE` | prod | Spring profile |
| `DATABASE_URL` | - | PostgreSQL JDBC URL |
| `DATABASE_USER` | - | Database username |
| `DATABASE_PASSWORD` | - | Database password |
| `SERVER_PORT` | 8080 | API port |
| `MANAGEMENT_SERVER_PORT` | 9090 | Management port |
| `LOGGING_LEVEL_ROOT` | WARN | Root log level |
| `LOGGING_LEVEL_COM_REST_API` | INFO | App log level |
| `JAVA_OPTS` | - | JVM options |

## Kubernetes Resource Requests

The chart includes default resource requests and limits. Adjust based on your cluster capacity:

**Development:**
- CPU: 100m request, 250m limit
- Memory: 256Mi request, 512Mi limit

**Production:**
- CPU: 500m request, 1000m limit
- Memory: 1Gi request, 2Gi limit

## Security

- **Non-root container** (runAsUser: 1000)
- **Read-only root filesystem** in security context
- **Network policies** supported (requires CNI plugin)
- **Pod security standards** enforced
- **RBAC** configured with ServiceAccount
- **Secrets** stored in Kubernetes (not in values files)

## Persistence

Optional persistent volume for logs:

```yaml
persistence:
  enabled: true
  storageClass: gp3
  size: 10Gi
  mountPath: /var/log/fusion-api
```

## Monitoring

### Prometheus Integration

Enable ServiceMonitor for Prometheus scraping:

```yaml
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s
```

Metrics endpoint: `http://<service>:9090/actuator/prometheus`

### CloudWatch Integration

Enable CloudWatch metrics export:

```yaml
cloudwatch:
  logGroup: /aws/eks/fusion-api-prod
  logStream: prod-cluster
  retentionDays: 30
```

## Best Practices

1. **Always use specific image tags** - Avoid `latest` in production
2. **Use separate values files** - Keep dev and prod overrides separate
3. **Set resource requests/limits** - Prevents resource contention
4. **Enable auto-scaling** - Handle traffic spikes automatically
5. **Use pod disruption budgets** - Minimize downtime during updates
6. **Configure health probes** - Ensures pod readiness
7. **Store secrets securely** - Use AWS Secrets Manager or Sealed Secrets
8. **Enable network policies** - Restrict pod traffic
9. **Monitor and log** - Use CloudWatch or Prometheus + Grafana
10. **Test upgrades** - Always test in staging first

## Support & Contribution

For issues or feature requests, please create an issue in the main application repository.

## License

Proprietary - Fusion Hackathon 2025

