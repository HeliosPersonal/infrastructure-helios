# GitHub Secrets

All secrets are managed in **Infisical** and synced automatically to GitHub Actions.

Verify at: **Repository → Settings → Secrets and variables → Actions**

Self-hosted runner tag: `helios` — must have Terraform ≥ 1.5, kubectl, Helm ≥ 3.0.

---

## Secrets Reference

### Azure (Terraform State Backend)

| Secret | Description |
|--------|-------------|
| `ARM_CLIENT_ID` | SP `sp-helios-terraform-ci` client ID |
| `ARM_CLIENT_SECRET` | SP client secret — expires 2027-02-23 |
| `ARM_TENANT_ID` | Azure AD tenant ID |
| `ARM_SUBSCRIPTION_ID` | Azure subscription ID (Overflow) |

### Kubernetes

| Secret | Description |
|--------|-------------|
| `KUBECONFIG` | Base64-encoded kubeconfig for helios cluster (`10.12.15.60`) |

Encode: `base64 -w 0 ~/.kube/config`

### Cloudflare

| Secret | Description |
|--------|-------------|
| `CLOUDFLARE_TUNNEL_TOKEN` | Tunnel token (Zero Trust → Networks → Tunnels → your tunnel → token) |
| `CLOUDFLARE_ORIGIN_CRT` | Base64-encoded `terraform/certs/origin.crt` |
| `CLOUDFLARE_ORIGIN_KEY` | Base64-encoded `terraform/certs/origin.key` |

Encode: `base64 -w 0 terraform/certs/origin.crt`

### Domain

| Variable | Value |
|----------|-------|
| `BASE_DOMAIN` | `devoverflow.org` |
| `INTERNAL_DOMAIN` | `helios` |
| `KEYCLOAK_SUBDOMAIN` | `keycloak` |

### Shared Services

| Secret | Description |
|--------|-------------|
| `PG_PASSWORD` | PostgreSQL admin password |
| `RABBIT_PASSWORD` | RabbitMQ admin password |
| `REDIS_PASSWORD` | Redis password |
| `TYPESENSE_API_KEY` | Typesense API key |
| `KEYCLOAK_ADMIN_PASSWORD` | Keycloak admin password |
| `KEYCLOAK_POSTGRES_PASSWORD` | Keycloak internal PostgreSQL password |

### Grafana Cloud

| Secret | Description |
|--------|-------------|
| `GRAFANA_CLOUD_API_TOKEN` | API token (all services) |
| `GRAFANA_CLOUD_PROMETHEUS_URL` | Prometheus remote write URL |
| `GRAFANA_CLOUD_PROMETHEUS_USER` | Prometheus instance ID |
| `GRAFANA_CLOUD_LOKI_URL` | Loki push URL |
| `GRAFANA_CLOUD_LOKI_USER` | Loki instance ID |
| `GRAFANA_CLOUD_TEMPO_URL` | Tempo OTLP endpoint |
| `GRAFANA_CLOUD_TEMPO_USER` | Tempo instance ID |

### Headlamp

| Secret | Description |
|--------|-------------|
| `HEADLAMP_OIDC_CLIENT_SECRET` | Keycloak OIDC client secret (Keycloak → client → Credentials tab) |

Fallback token login:
```bash
kubectl get secret headlamp-token -n monitoring -o jsonpath='{.data.token}' | base64 -d
```
