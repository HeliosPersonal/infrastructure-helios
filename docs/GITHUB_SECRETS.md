# GitHub Secrets Configuration

This document lists all secrets that need to be configured in your GitHub repository for CI/CD deployment.

## Required GitHub Secrets

Navigate to: **Repository → Settings → Secrets and variables → Actions → New repository secret**

### Kubernetes Configuration

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `KUBECONFIG` | Base64-encoded kubeconfig file content | `cat ~/.kube/config \| base64 -w 0` |

### Cloudflare

| Secret Name | Description |
|-------------|-------------|
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token for DDNS updates |

### Let's Encrypt

| Secret Name | Description |
|-------------|-------------|
| `LETSENCRYPT_EMAIL` | Email for certificate notifications |

### PostgreSQL

| Secret Name | Description |
|-------------|-------------|
| `PG_STAGING_PASSWORD` | Staging database password |
| `PG_PRODUCTION_PASSWORD` | Production database password |

### RabbitMQ

| Secret Name | Description |
|-------------|-------------|
| `RABBIT_STAGING_PASSWORD` | Staging RabbitMQ password |
| `RABBIT_PRODUCTION_PASSWORD` | Production RabbitMQ password |

### Typesense

| Secret Name | Description |
|-------------|-------------|
| `TYPESENSE_STAGING_API_KEY` | Staging Typesense API key |
| `TYPESENSE_PRODUCTION_API_KEY` | Production Typesense API key |

### Keycloak

| Secret Name | Description |
|-------------|-------------|
| `KEYCLOAK_ADMIN_PASSWORD` | Keycloak admin user password |
| `KEYCLOAK_POSTGRES_PASSWORD` | Keycloak's embedded PostgreSQL password |

### Grafana Cloud

| Secret Name | Description |
|-------------|-------------|
| `GRAFANA_CLOUD_API_TOKEN` | Grafana Cloud API token |
| `GRAFANA_CLOUD_PROMETHEUS_URL` | Prometheus remote write URL |
| `GRAFANA_CLOUD_PROMETHEUS_USER` | Prometheus username (Instance ID) |
| `GRAFANA_CLOUD_LOKI_URL` | Loki URL |
| `GRAFANA_CLOUD_LOKI_USER` | Loki username |
| `GRAFANA_CLOUD_TEMPO_URL` | Tempo OTLP endpoint |
| `GRAFANA_CLOUD_TEMPO_USER` | Tempo username |

---

## Quick Setup Script

Run this locally to generate the secrets values (copy output to GitHub):

```bash
#!/bin/bash

echo "=== KUBECONFIG (base64) ==="
cat ~/.kube/config | base64 -w 0
echo -e "\n"

echo "=== Generate secure passwords ==="
echo "PG_STAGING_PASSWORD: $(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)"
echo "PG_PRODUCTION_PASSWORD: $(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)"
echo "RABBIT_STAGING_PASSWORD: $(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)"
echo "RABBIT_PRODUCTION_PASSWORD: $(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)"
echo "TYPESENSE_STAGING_API_KEY: $(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)"
echo "TYPESENSE_PRODUCTION_API_KEY: $(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)"
echo "KEYCLOAK_ADMIN_PASSWORD: $(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)"
echo "KEYCLOAK_POSTGRES_PASSWORD: $(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)"
```

---

## GitHub Variables (Non-Sensitive)

Navigate to: **Repository → Settings → Secrets and variables → Actions → Variables → New repository variable**

| Variable Name | Description | Example |
|---------------|-------------|---------|
| `BASE_DOMAIN` | Base domain for services | `devoverflow.org` |
| `INTERNAL_DOMAIN` | Internal network domain | `helios` |
| `KEYCLOAK_SUBDOMAIN` | Keycloak subdomain | `keycloak` |

---

## Self-Hosted Runner Configuration

The workflow uses `runs-on: self-hosted` to run on your Helios machine.

### Runner Requirements

Ensure your self-hosted runner has:

1. **Terraform** installed:
   ```bash
   # Install Terraform
   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform
   ```

2. **kubectl** installed and configured:
   ```bash
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   ```

3. **Helm** installed:
   ```bash
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   ```

4. **Access to kubeconfig** (usually at `~/.kube/config` on the runner)

---

## Verification

After setting up secrets, verify in GitHub Actions:

```yaml
- name: Verify Secrets
  run: |
    echo "Checking if secrets are set..."
    if [ -z "${{ secrets.PG_STAGING_PASSWORD }}" ]; then
      echo "❌ PG_STAGING_PASSWORD not set"
      exit 1
    fi
    echo "✅ All required secrets are configured"
```

