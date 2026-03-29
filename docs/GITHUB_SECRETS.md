# GitHub Secrets Configuration

All secrets are managed in **Infisical** and synced automatically to GitHub Actions secrets.

Navigate to: **Repository → Settings → Secrets and variables → Actions** to verify.

---

## Secrets Reference

### Azure Terraform State Backend

Required for `terraform init` to authenticate against Azure Blob Storage (`stheliosinfrastate`).

| Secret | Description |
|---|---|
| `ARM_CLIENT_ID` | Service Principal `sp-helios-terraform-ci` client ID |
| `ARM_CLIENT_SECRET` | Service Principal client secret (expires 2027-02-23) |
| `ARM_TENANT_ID` | Azure AD tenant ID |
| `ARM_SUBSCRIPTION_ID` | Azure subscription ID (Overflow) |

### Kubernetes

| Secret | Description |
|---|---|
| `KUBECONFIG` | Base64-encoded kubeconfig for Helios k3s cluster (`10.12.15.60`) |

Encode with: `base64 -w 0 ~/.kube/config`

### Cloudflare Origin Certificates

The `terraform/certs/` directory is gitignored. Certificates are stored as base64-encoded secrets.

| Secret | Description |
|---|---|
| `CLOUDFLARE_ORIGIN_CRT` | Base64-encoded `origin.crt` |
| `CLOUDFLARE_ORIGIN_KEY` | Base64-encoded `origin.key` |

Encode with: `base64 -w 0 terraform/certs/origin.crt`

### Cloudflare

| Secret | Description |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token for DDNS updates |

### Domain Configuration

| Secret | Value |
|---|---|
| `BASE_DOMAIN` | `devoverflow.org` |
| `INTERNAL_DOMAIN` | `helios` |
| `KEYCLOAK_SUBDOMAIN` | `keycloak` |

### PostgreSQL

| Secret | Description |
|---|---|
| `PG_PASSWORD` | PostgreSQL admin password (shared instance) |

### RabbitMQ

| Secret | Description |
|---|---|
| `RABBIT_PASSWORD` | RabbitMQ admin password (shared instance) |

### Redis

| Secret | Description |
|---|---|
| `REDIS_PASSWORD` | Redis password (shared instance) |

### Typesense

| Secret | Description |
|---|---|
| `TYPESENSE_API_KEY` | Typesense API key (shared instance) |

### Keycloak

| Secret | Description |
|---|---|
| `KEYCLOAK_ADMIN_PASSWORD` | Keycloak admin user password |
| `KEYCLOAK_POSTGRES_PASSWORD` | Keycloak's internal PostgreSQL password |

### Grafana Cloud

| Secret | Description |
|---|---|
| `GRAFANA_CLOUD_API_TOKEN` | Grafana Cloud API token (used for all services) |
| `GRAFANA_CLOUD_PROMETHEUS_URL` | Prometheus remote write URL |
| `GRAFANA_CLOUD_PROMETHEUS_USER` | Prometheus instance ID |
| `GRAFANA_CLOUD_LOKI_URL` | Loki push URL |
| `GRAFANA_CLOUD_LOKI_USER` | Loki instance ID |
| `GRAFANA_CLOUD_TEMPO_URL` | Tempo OTLP endpoint |
| `GRAFANA_CLOUD_TEMPO_USER` | Tempo instance ID |

### Headlamp (K8s Dashboard)

| Secret | Description |
|---|---|
| `HEADLAMP_OIDC_CLIENT_SECRET` | Keycloak OIDC client secret for Headlamp SSO (from Keycloak → client → Credentials tab). **Required**. |

> **Token login still works** even when OIDC is enabled:
> ```bash
> kubectl get secret headlamp-token -n monitoring -o jsonpath='{.data.token}' | base64 -d
> ```

---

## Azure Infrastructure Setup (one-time, already done)

Documented for reference. Resources already exist in the **Overflow** subscription.

```bash
az group create --name rg-helios-tfstate --location westeurope

az storage account create \
  --name stheliosinfrastate \
  --resource-group rg-helios-tfstate \
  --location westeurope \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2

az storage container create \
  --name tfstate \
  --account-name stheliosinfrastate \
  --auth-mode login

az storage account blob-service-properties update \
  --account-name stheliosinfrastate \
  --enable-versioning true

# Create Service Principal scoped to storage account only
STORAGE_ID=$(az storage account show \
  --name stheliosinfrastate \
  --resource-group rg-helios-tfstate \
  --query id -o tsv)

# Note: requires Storage Blob Data Owner (not Contributor) for AAD auth locking
az ad sp create-for-rbac \
  --name sp-helios-terraform-ci \
  --role "Storage Blob Data Owner" \
  --scopes "$STORAGE_ID"
```

See [AZURE_TFSTATE_BACKEND.md](AZURE_TFSTATE_BACKEND.md) for full details.

---

## Self-Hosted Runner Requirements

The workflow runs on the `helios` self-hosted runner. Ensure it has:

- **Terraform** >= 1.5
- **kubectl** connected to the k3s cluster
- **Helm** >= 3.0

The runner does **not** need pre-configured Azure credentials — `ARM_*` env vars are injected from GitHub Secrets at runtime.
