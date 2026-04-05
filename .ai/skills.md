# Helios — Operational Skills

## Terraform

```bash
cd terraform

# Deploy
terraform plan  -var-file="terraform.secret.tfvars"
terraform apply -var-file="terraform.secret.tfvars"

# Target a single component
terraform apply -var-file="terraform.secret.tfvars" -target=helm_release.postgres

# Inspect state
terraform state list
terraform output
```

## kubectl

```bash
# All pods
kubectl get pods -A

# Port-forward shared services
kubectl port-forward -n infra-production svc/postgres   5432:5432
kubectl port-forward -n infra-production svc/rabbitmq  15672:15672
kubectl port-forward -n infra-production svc/redis      6379:6379
kubectl port-forward -n infra-production svc/typesense  8108:8108

# Logs
kubectl logs -n ingress    -l app=cloudflared                    --tail=40
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy       --tail=40

# Tunnel health
kubectl -n ingress get pods -l app=cloudflared
kubectl -n ingress port-forward deploy/cloudflared 2000:2000
curl -s localhost:2000/ready

# Headlamp token (fallback when OIDC unavailable)
kubectl get secret headlamp-token -n monitoring -o jsonpath='{.data.token}' | base64 -d

# Cloudflare origin certs
kubectl get secret cloudflare-origin -n infra-production
kubectl get secret cloudflare-origin -n monitoring
```

## PostgreSQL — Create Database

```bash
kubectl exec -n infra-production postgres-0 -- \
  psql -U postgres -c "CREATE DATABASE staging_myapp;"
```

## RabbitMQ — Create Vhost

```bash
kubectl exec -n infra-production rabbitmq-0 -- rabbitmqctl add_vhost staging
kubectl exec -n infra-production rabbitmq-0 -- \
  rabbitmqctl set_permissions -p staging admin ".*" ".*" ".*"
```

## Redis — Safe Operations

```bash
kubectl port-forward -n infra-production svc/redis 6379:6379

# Scan (never use KEYS *)
redis-cli -a <password> --scan --pattern "staging:myapp:*"

# Delete only one app's keys
redis-cli -a <password> --scan --pattern "staging:myapp:*" \
  | xargs --no-run-if-empty redis-cli -a <password> DEL

# Health
redis-cli -a <password> PING
redis-cli -a <password> INFO memory
```

## Stuck Namespace Fix

```bash
./scripts/clean-stuck-namespace.sh <namespace>
```

## Terraform State Recovery

Via Azure Portal:
```
stheliosinfrastate → Containers → tfstate → infrastructure-helios.tfstate → Version history → Promote
```

Via CLI:
```bash
terraform state pull > terraform.tfstate.backup
# edit / fix the state file
terraform state push terraform.tfstate.fixed
```

## Consuming Infrastructure from Another Project

```hcl
# data.tf
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
  postgres_host = data.terraform_remote_state.infra.outputs.postgres_host
  redis_host    = data.terraform_remote_state.infra.outputs.redis_host
  rabbitmq_host = data.terraform_remote_state.infra.outputs.rabbitmq_host
  typesense_url = data.terraform_remote_state.infra.outputs.typesense_url
  keycloak_url  = data.terraform_remote_state.infra.outputs.keycloak_external_url
  ns_staging    = data.terraform_remote_state.infra.outputs.namespace_apps_staging
  ns_production = data.terraform_remote_state.infra.outputs.namespace_apps_production
}
```

## Adding a New Helm-Based Service

1. Create `terraform/<service>.tf` — follow pattern from `postgres.tf` or `redis.tf`
2. Add variables to `variables.tf`
3. Add outputs to `outputs.tf`
4. If it needs observability: add scrape target to `values/alloy-values.yaml` (see `docs/OBSERVABILITY.md`)
5. If it needs ingress: add annotation block to `ingress.tf`

## Alloy Config Changes

The Alloy River config lives in `terraform/values/alloy-values.yaml` under `alloy.configMap.content`.
After editing, apply terraform — no manual pod restart needed (Helm handles the ConfigMap rollout).
