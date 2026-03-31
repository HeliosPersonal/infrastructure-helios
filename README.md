
# Infrastructure Helios

**Shared Kubernetes infrastructure for home lab / self-hosted environments**

This repository provides reusable infrastructure components managed by Terraform, designed for K3s clusters with dynamic IP addresses. All services are exposed via Cloudflare for DDoS protection and SSL termination.

## 🏗️ Architecture Philosophy

**Single Instance, Multi-Tenant:** All infrastructure services (PostgreSQL, RabbitMQ, Redis, Typesense) run as single shared instances. Applications create their own databases, vhosts, key namespaces, and collections within these instances for staging/production isolation. This approach:

- ✅ Reduces resource consumption (1 PostgreSQL vs 2)
- ✅ Simplifies maintenance and backups
- ✅ Mirrors production-grade multi-tenant architecture
- ✅ Applications control their own data isolation

## What's Inside

| Component | Description | Instance |
|-----------|-------------|----------|
| **PostgreSQL** | Relational database (Bitnami Helm) | Single shared instance |
| **RabbitMQ** | Message broker (AMQP) | Single shared instance |
| **Redis** | In-memory cache & session store (Bitnami Helm) | Single shared instance |
| **Redis Insight** | Browser-based GUI for Redis management | Single shared instance |
| **Typesense** | Fast search engine with Dashboard UI | Single shared instance |
| **Keycloak** | Identity & Access Management (OAuth2/OIDC) | Production |
| **Headlamp** | Kubernetes Dashboard with OIDC SSO | Cluster-wide |
| **Ollama** | Local LLM inference service | Production |
| **NGINX Ingress** | HTTP routing controller | Cluster-wide |
| **Grafana Alloy** | Observability agent → Grafana Cloud | Cluster-wide |
| **Cloudflare DDNS** | Auto-updates DNS for dynamic home IP | Cluster-wide |


## Architecture

```
Internet → Cloudflare (DNS/WAF/SSL) → Home Router → K3s Cluster
                                                      ├─ NGINX Ingress
                                                      ├─ infra-production (PostgreSQL, RabbitMQ, Redis, Typesense, Keycloak, Ollama)
                                                      │   └─ Applications connect and create:
                                                      │      ├─ staging_myapp (database)
                                                      │      ├─ production_myapp (database)
                                                      │      ├─ staging_vhost (RabbitMQ)
                                                      │      ├─ production_vhost (RabbitMQ)
                                                      │      ├─ staging:myapp:* (Redis keys)
                                                      │      ├─ production:myapp:* (Redis keys)
                                                      │      ├─ staging_* (Typesense collections)
                                                      │      └─ production_* (Typesense collections)
                                                      ├─ apps-staging (Your staging applications)
                                                      ├─ apps-production (Your production applications)
                                                      └─ monitoring (Grafana Alloy, Headlamp)
```

## Quick Start

### 1. Prerequisites

- **Terraform** >= 1.5
- **kubectl** with K3s cluster access
- **Helm** >= 3.0
- **Cloudflare account** with domain configured
- **Grafana Cloud account** (free tier sufficient)

### 2. Cloudflare Setup

1. Add your domain to Cloudflare
2. Create API token: **My Profile → API Tokens → Create Token** (use "Edit zone DNS" template)
3. Create DNS A records (any IP, DDNS will update):
   - `@` (root)
   - `www`
   - `staging`
   - `keycloak`
4. Set SSL/TLS mode to **"Flexible"** or **"Full"** (Cloudflare Universal SSL handles certificates)
5. Enable **"Always Use HTTPS"** under SSL/TLS → Edge Certificates

### 3. Configure Terraform

```bash
cd terraform

# Copy and edit configuration
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Set base_domain, storage sizes, subdomains

# Create secrets file
touch terraform.secret.tfvars
chmod 600 terraform.secret.tfvars
vim terraform.secret.tfvars  # Add passwords, API keys, Grafana Cloud settings
```

**Required secrets** (`terraform.secret.tfvars`):
```hcl
# Cloudflare
cloudflare_api_token           = "your-cloudflare-token"

# Shared Infrastructure
pg_password                    = "secure-password"        # Single PostgreSQL instance
rabbit_password                = "secure-password"        # Single RabbitMQ instance
redis_password                 = "secure-password"        # Single Redis instance
typesense_api_key              = "secure-key"             # Single Typesense instance

# Keycloak
keycloak_admin_password        = "secure-password"
keycloak_postgres_password     = "secure-password"

# Grafana Cloud
grafana_cloud_api_token        = "your-grafana-token"
grafana_cloud_prometheus_url   = "https://prometheus-prod-XX-XX.grafana.net"
grafana_cloud_prometheus_user  = "123456"
grafana_cloud_loki_url         = "https://logs-prod-XX.grafana.net"
grafana_cloud_loki_user        = "123456"
grafana_cloud_tempo_url        = "https://tempo-prod-XX.grafana.net:443"
grafana_cloud_tempo_user       = "123456"
```

### 4. Deploy

```bash
cd terraform

# ARM_* env vars must be set (see docs/AZURE_TFSTATE_BACKEND.md for details)

# Initialize (connects to Azure Blob state backend)
terraform init

# Review plan
terraform plan -var-file="terraform.secret.tfvars"

# Apply
terraform apply -var-file="terraform.secret.tfvars"
```

### 5. Verify

```bash
# Check all pods are running
kubectl get pods -A

# Check DDNS updates
kubectl logs -n kube-system -l app=cloudflare-ddns

# Access services
https://keycloak.your-domain.com    # Keycloak admin console
https://staging.your-domain.com      # Your staging apps
```

---

## Terraform State

State is stored in Azure Blob Storage. See [docs/AZURE_TFSTATE_BACKEND.md](docs/AZURE_TFSTATE_BACKEND.md) for full details.

```
rg-helios-tfstate / stheliosinfrastate / tfstate / infrastructure-helios.tfstate
```

---

## Using in Other Projects

Other projects can consume this infrastructure via Terraform remote state:

```hcl
# your-project/terraform/data.tf
data "terraform_remote_state" "infra" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-helios-tfstate"
    storage_account_name = "stheliosinfrastate"
    container_name       = "tfstate"
    key                  = "infrastructure-helios.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  postgres_host     = data.terraform_remote_state.infra.outputs.postgres_host
  rabbitmq_host     = data.terraform_remote_state.infra.outputs.rabbitmq_host
  redis_host        = data.terraform_remote_state.infra.outputs.redis_host
  typesense_url     = data.terraform_remote_state.infra.outputs.typesense_url
  keycloak_url      = data.terraform_remote_state.infra.outputs.keycloak_external_url
  base_domain       = data.terraform_remote_state.infra.outputs.base_domain
  namespace_staging = data.terraform_remote_state.infra.outputs.namespace_apps_staging
  namespace_prod    = data.terraform_remote_state.infra.outputs.namespace_apps_production
}
```

**See** `examples/project-integration/` for a complete example.

---

## Available Outputs

| Category | Outputs |
|----------|---------|
| **Namespaces** | `namespace_infra_production`, `namespace_apps_staging`, `namespace_apps_production` |
| **PostgreSQL** | `postgres_host`, `postgres_port`, `postgres_connection_string` (shared instance) |
| **RabbitMQ** | `rabbitmq_host`, `rabbitmq_amqp_port`, `rabbitmq_management_port`, `rabbitmq_connection_string` (shared instance) |
| **Redis** | `redis_host`, `redis_port`, `redis_connection_string` (shared instance) |
| **Redis Insight** | `redis_insight_url` |
| **Typesense** | `typesense_host`, `typesense_port`, `typesense_url` (shared instance) |
| **Keycloak** | `keycloak_internal_url`, `keycloak_external_url`, `keycloak_admin_user` |
| **Ollama** | `ollama_url` |
| **Monitoring** | `otlp_grpc_endpoint`, `otlp_http_endpoint` |
| **Domains** | `base_domain`, `internal_domain` |

**Full details**: Run `terraform output` or see `terraform/outputs.tf`

---

## Directory Structure

```
infrastructure-helios/
├── terraform/
│   ├── provider.tf           # Providers + Azure Blob state backend
│   ├── variables.tf          # All configurable variables
│   ├── outputs.tf            # Outputs for consuming projects
│   ├── namespaces.tf         # K8s namespaces
│   ├── postgres.tf           # Shared PostgreSQL instance
│   ├── rabbitmq.tf           # Shared RabbitMQ instance
│   ├── redis.tf              # Shared Redis instance + Redis Insight UI
│   ├── keycloak.tf           # Identity management (OAuth2/OIDC)
│   ├── headlamp.tf           # Kubernetes dashboard (OIDC-enabled)
│   ├── typesense.tf          # Shared Typesense instance + Dashboard UI
│   ├── ollama.tf             # Local LLM inference service
│   ├── ingress.tf            # NGINX ingress controller + routes
│   ├── monitoring.tf         # Grafana Alloy + kube-state-metrics + node-exporter
│   ├── ddns.tf               # Cloudflare DDNS
│   ├── keycloak-headlamp-realm-import.json  # Keycloak partial import for Headlamp OIDC
│   ├── terraform.tfvars      # Non-sensitive config (gitignored)
│   ├── terraform.secret.tfvars # Secrets (gitignored)
│   ├── terraform.tfvars.example
│   ├── certs/                # Cloudflare origin certs (gitignored)
│   └── values/
│       ├── alloy-values.yaml
│       └── ollama-values.yaml
├── scripts/
│   ├── clean-stuck-namespace.sh    # Fix namespaces stuck in Terminating state
│   └── configure-k3s-oidc.sh       # Configure k3s API server for Keycloak OIDC
├── docs/
│   ├── AZURE_TFSTATE_BACKEND.md
│   ├── GITHUB_SECRETS.md
│   ├── QUICK_REFERENCE.md
│   └── REDIS.md
└── examples/
    └── project-integration/
```

## Deployment

```bash
cd terraform

# ARM_* env vars must be set for Azure backend authentication
# (e.g., via shell profile or CI environment variables)

# Initialize (connects to Azure Blob state backend)
terraform init

# Review plan
terraform plan -var-file="terraform.secret.tfvars"

# Apply
terraform apply -var-file="terraform.secret.tfvars"
```

---

## Important Links

- **[GitHub Secrets Setup](docs/GITHUB_SECRETS.md)** — Complete list of required secrets
- **[Azure State Backend](docs/AZURE_TFSTATE_BACKEND.md)** — Azure infrastructure details
- **[Project Integration Example](examples/project-integration/)** — How to consume outputs
- **Cloudflare**: https://dash.cloudflare.com
- **Grafana Cloud**: https://overflowproject.grafana.net
- **Keycloak Docs**: https://www.keycloak.org/docs/latest
- **Typesense Docs**: https://typesense.org/docs

---

## Customization

### Change Domains

Edit `terraform/terraform.tfvars`:
```hcl
base_domain        = "your-domain.com"
keycloak_subdomain = "auth"
ddns_subdomains    = ["www", "staging", "auth"]
```

### Disable Components

```hcl
# Disable Ollama
ollama_enabled = false
```

### Adjust Resources

```hcl
# PostgreSQL storage
pg_storage_size = "20Gi"

# Ollama memory
ollama_memory_limit = "16Gi"

# Typesense storage
typesense_storage_size = "10Gi"
```

## Common Operations

```bash
# View managed resources
terraform state list

# Target specific component
terraform apply -var-file="terraform.secret.tfvars" -target=helm_release.postgres

# Check DDNS logs
kubectl logs -n kube-system -l app=cloudflare-ddns -f

# Check Cloudflare origin TLS secrets
kubectl get secret cloudflare-origin -n infra-production
kubectl get secret cloudflare-origin -n monitoring

# Access Keycloak admin
# https://keycloak.your-domain.com/admin
# Username: admin
# Password: (from terraform.secret.tfvars)

# Port-forward to shared services
kubectl port-forward -n infra-production svc/postgres 5432:5432
kubectl port-forward -n infra-production svc/rabbitmq 15672:15672  # Management UI
kubectl port-forward -n infra-production svc/redis 6379:6379
kubectl port-forward -n infra-production svc/typesense 8108:8108

# Access management UIs (internal domain)
http://rabbit.helios           # RabbitMQ Management
http://typesense.helios         # Typesense Dashboard
http://typesense-api.helios     # Typesense API
https://redisinsight.your-domain.com  # Redis Insight
```

---

## Documentation

| Document | Description |
|---|---|
| [docs/AZURE_TFSTATE_BACKEND.md](docs/AZURE_TFSTATE_BACKEND.md) | Azure infrastructure for Terraform state storage — what was created, why, and how it works |
| [docs/GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md) | All secrets and variables required for deployment (managed via Infisical) |
| [docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md) | Connection strings and endpoints for all shared infrastructure services |
| [docs/REDIS.md](docs/REDIS.md) | Redis setup details, key naming conventions, consuming from other projects, and troubleshooting |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **DDNS not updating** | Check pod logs: `kubectl logs -n kube-system -l app=cloudflare-ddns` |
| **TLS/SSL errors** | Verify Cloudflare origin certs exist: `kubectl get secret cloudflare-origin -n infra-production` |
| **PostgreSQL won't start** | Check PVC: `kubectl get pvc -n infra-production` |
| **Typesense health check failing** | Verify API key in `terraform.secret.tfvars` |
| **Keycloak hostname errors** | Check `keycloak.hostname` matches your domain |
| **Can't create database** | Connect to postgres and run: `CREATE DATABASE mydb;` |
| **RabbitMQ vhost issues** | Access Management UI and create vhost manually or via API |

---

## License

MIT

