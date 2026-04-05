# infrastructure-helios

Terraform-managed K8s infrastructure for the **helios** home lab cluster (k3s, `10.12.15.60`).
Single shared instances of all services. Traffic: `Internet → Cloudflare → cloudflared → NGINX ingress → services`.

## Cluster

| | |
|---|---|
| Cluster | helios (k3s) |
| Node IP | `10.12.15.60` |
| Domain | `devoverflow.org` |
| Internal domain | `*.helios` |
| State | Azure Blob (`stheliosinfrastate/tfstate/infrastructure-helios.tfstate`) |

**Namespaces:** `infra-production` · `apps-staging` · `apps-production` · `ingress` · `monitoring`

**Shared services** (`infra-production`): PostgreSQL · RabbitMQ · Redis · Typesense · Keycloak · Ollama · Redis Insight

**Cluster-wide** (`ingress` / `monitoring`): NGINX Ingress · Grafana Alloy · Headlamp · cloudflared

## Key Files

| File | Purpose |
|------|---------|
| `terraform/provider.tf` | Azure Blob state backend + providers |
| `terraform/variables.tf` | All config variables |
| `terraform/outputs.tf` | Outputs for consuming projects |
| `terraform/values/alloy-values.yaml` | Grafana Alloy River config (observability pipeline) |
| `terraform/terraform.tfvars` | Non-secret config — gitignored |
| `terraform/terraform.secret.tfvars` | All secrets — gitignored |
| `scripts/clean-stuck-namespace.sh` | Fix namespaces stuck in Terminating |
| `scripts/configure-k3s-oidc.sh` | Configure k3s API server for Keycloak OIDC |

## Deploy

```bash
# Local — ARM_* env vars loaded from ~/.config/fish/conf.d/azure-terraform.fish
cd terraform
terraform init
terraform plan  -var-file="terraform.secret.tfvars"
terraform apply -var-file="terraform.secret.tfvars"
```

CI: push to `main` → plan runs automatically → apply requires manual approval (GitHub Environment: `production`).

## Naming Conventions

| Resource | Pattern | Example |
|----------|---------|---------|
| PostgreSQL DB | `{env}_{app}` | `staging_devoverflow` |
| RabbitMQ vhost | `staging` / `production` (shared) or `{env}-{app}` | `staging-devoverflow` |
| Redis key prefix | `{env}:{app}:` | `staging:overflow:` |
| Typesense collection | `{env}_{app}_{name}` | `staging_devoverflow_questions` |

## Docs

| File | When to read |
|------|-------------|
| `docs/QUICK_REFERENCE.md` | Connection strings for all services |
| `docs/OBSERVABILITY.md` | Instrument a new service / configure Alloy |
| `docs/CLOUDFLARE_TUNNEL.md` | Tunnel setup and troubleshooting |
| `docs/AZURE_TFSTATE_BACKEND.md` | State backend details and recovery |
| `docs/GITHUB_SECRETS.md` | All CI/CD secrets reference |
| `docs/REDIS.md` | Redis patterns and integration guide |
| `.ai/skills.md` | Common operational commands (quick copy-paste) |
