# Quick Reference — Shared Infrastructure

## Connection Strings

### PostgreSQL

```
Host:   postgres.infra-production.svc.cluster.local
Port:   5432
User:   postgres
Pass:   terraform.secret.tfvars → pg_password
DB:     create your own (naming: staging_myapp / production_myapp)
```
```
postgres://postgres:PASSWORD@postgres.infra-production.svc.cluster.local:5432/staging_myapp
```

### RabbitMQ

```
Host:         rabbitmq.infra-production.svc.cluster.local
AMQP port:    5672
Mgmt port:    15672
User:         admin
Pass:         terraform.secret.tfvars → rabbit_password
Vhost:        create your own (naming: staging / staging-myapp)
Mgmt UI:      http://rabbit.helios:15672
```
```
amqp://admin:PASSWORD@rabbitmq.infra-production.svc.cluster.local:5672/staging
```

### Redis

```
Host:          redis.infra-production.svc.cluster.local
Port:          6379
DB:            0 (always — use key prefixes, not DB numbers)
Pass:          terraform.secret.tfvars → redis_password
Key prefix:    staging:myapp: / production:myapp:
Redis Insight: https://redisinsight.devoverflow.org
```
```
redis://:PASSWORD@redis.infra-production.svc.cluster.local:6379/0
```

### Typesense

```
Host:         typesense.infra-production.svc.cluster.local
Port:         8108
API Key:      terraform.secret.tfvars → typesense_api_key
Collections:  prefix with staging_myapp_ / production_myapp_
Dashboard:    http://typesense.helios
```
```
http://typesense.infra-production.svc.cluster.local:8108
```

### Keycloak

```
Internal: http://keycloak.infra-production.svc.cluster.local:8080
External: https://keycloak.devoverflow.org
User:     admin
Pass:     terraform.secret.tfvars → keycloak_admin_password
```

### Grafana Alloy (OTLP)

```
gRPC:  grafana-alloy.monitoring.svc.cluster.local:4317
HTTP:  http://grafana-alloy.monitoring.svc.cluster.local:4318
```

---

## Naming Conventions

| Resource | Pattern | Example |
|----------|---------|---------|
| PostgreSQL DB | `{env}_{app}` | `staging_devoverflow` |
| RabbitMQ vhost | `staging` / `production` or `{env}-{app}` | `staging-devoverflow` |
| Redis key prefix | `{env}:{app}:` | `staging:overflow:` |
| Typesense collection | `{env}_{app}_{name}` | `staging_devoverflow_questions` |

---

## Terraform Remote State

```hcl
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

---

## Secrets in Application Namespace

```bash
kubectl create secret generic postgres-password  -n apps-staging --from-literal=password='...'
kubectl create secret generic rabbitmq-password  -n apps-staging --from-literal=password='...'
kubectl create secret generic redis-password     -n apps-staging --from-literal=password='...'
kubectl create secret generic typesense-api-key  -n apps-staging --from-literal=api-key='...'
```
