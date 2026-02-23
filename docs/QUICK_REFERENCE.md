# Quick Reference: Connecting to Shared Infrastructure

## 🔌 Connection Details

### PostgreSQL (Shared Instance)
```yaml
Host: postgres.infra-production.svc.cluster.local
Port: 5432
User: postgres
Password: <from infrastructure terraform.secret.tfvars>
Database: <you create your own>
```

**Database Naming Convention:**
```
staging_<appname>      # e.g., staging_devoverflow, staging_api
production_<appname>   # e.g., production_devoverflow, production_api
```

**Connection String Template:**
```
postgres://postgres:PASSWORD@postgres.infra-production.svc.cluster.local:5432/staging_myapp
```

### RabbitMQ (Shared Instance)
```yaml
Host: rabbitmq.infra-production.svc.cluster.local
AMQP Port: 5672
Management UI: 15672
User: admin
Password: <from infrastructure terraform.secret.tfvars>
Vhost: <you create your own or use staging/production>
```

**Vhost Convention:**
```
staging       # Shared vhost for all staging apps
production    # Shared vhost for all production apps

# OR per-app isolation:
staging-<appname>      # e.g., staging-devoverflow
production-<appname>   # e.g., production-devoverflow
```

**Connection String Template:**
```
amqp://admin:PASSWORD@rabbitmq.infra-production.svc.cluster.local:5672/staging
```

**Management UI (Internal):**
```
http://rabbit.helios:15672
```

### Typesense (Shared Instance)
```yaml
Host: typesense.infra-production.svc.cluster.local
Port: 8108
API Key: <from infrastructure terraform.secret.tfvars>
Collections: <you create your own with prefixes>
```

**Collection Naming Convention:**
```
staging_<appname>_<collection>      # e.g., staging_devoverflow_questions
production_<appname>_<collection>   # e.g., production_devoverflow_users
```

**URL Template:**
```
http://typesense.infra-production.svc.cluster.local:8108
```

**Dashboard UI (Internal):**
```
http://typesense.helios
```

### Keycloak (Production Only)
```yaml
Internal: http://keycloak.infra-production.svc.cluster.local:8080
External: https://keycloak.<your-domain>
Admin User: admin
Admin Password: <from infrastructure terraform.secret.tfvars>
```

---

## 🏗️ Initial Setup (Per Application)

### 1. Create PostgreSQL Database

**Option A: Using kubectl exec**
```bash
kubectl exec -n infra-production postgres-0 -- \
  psql -U postgres -c "CREATE DATABASE staging_myapp;"
```

**Option B: Using Terraform (Recommended)**
```hcl
resource "kubernetes_job" "create_database" {
  metadata {
    name      = "create-db-staging"
    namespace = var.app_namespace
  }
  spec {
    template {
      spec {
        container {
          name    = "psql"
          image   = "postgres:16"
          command = ["psql", "-h", var.postgres_host, "-U", "postgres", 
                     "-c", "CREATE DATABASE IF NOT EXISTS staging_myapp;"]
          env {
            name = "PGPASSWORD"
            value_from {
              secret_key_ref {
                name = "postgres-password"
                key  = "password"
              }
            }
          }
        }
        restart_policy = "OnFailure"
      }
    }
  }
}
```

**Option C: Using init container in your app**
```yaml
initContainers:
  - name: create-database
    image: postgres:16
    command:
      - psql
      - -h
      - postgres.infra-production.svc.cluster.local
      - -U
      - postgres
      - -c
      - CREATE DATABASE IF NOT EXISTS staging_myapp;
    env:
      - name: PGPASSWORD
        valueFrom:
          secretKeyRef:
            name: postgres-password
            key: password
```

### 2. Create RabbitMQ Vhost

**Option A: Using Management UI**
1. Open http://rabbit.helios (or port-forward)
2. Login with admin credentials
3. Go to "Admin" tab → "Virtual Hosts"
4. Add new vhost: `staging` or `staging-myapp`

**Option B: Using rabbitmqadmin CLI**
```bash
kubectl exec -n infra-production rabbitmq-0 -- \
  rabbitmqctl add_vhost staging
  
kubectl exec -n infra-production rabbitmq-0 -- \
  rabbitmqctl set_permissions -p staging admin ".*" ".*" ".*"
```

**Option C: Using HTTP API**
```bash
curl -u admin:PASSWORD -X PUT \
  http://rabbitmq.infra-production.svc.cluster.local:15672/api/vhosts/staging
```

### 3. Create Typesense Collections

**In your application code:**
```javascript
// Node.js example
const Typesense = require('typesense');

const client = new Typesense.Client({
  nodes: [{
    host: 'typesense.infra-production.svc.cluster.local',
    port: 8108,
    protocol: 'http'
  }],
  apiKey: process.env.TYPESENSE_API_KEY,
});

// Use prefixed collection names
await client.collections().create({
  name: 'staging_myapp_questions',
  fields: [
    { name: 'title', type: 'string' },
    { name: 'body', type: 'string' },
  ]
});
```

---

## 📦 Terraform Remote State Example

```hcl
# data.tf
data "terraform_remote_state" "infra" {
  backend = "kubernetes"
  config = {
    secret_suffix = "infrastructure-helios"
    namespace     = "kube-system"
    config_path   = "~/.kube/config"
  }
}

# locals.tf
locals {
  # Infrastructure endpoints (same for staging and production)
  postgres_host     = data.terraform_remote_state.infra.outputs.postgres_host
  postgres_port     = data.terraform_remote_state.infra.outputs.postgres_port
  rabbitmq_host     = data.terraform_remote_state.infra.outputs.rabbitmq_host
  rabbitmq_port     = data.terraform_remote_state.infra.outputs.rabbitmq_amqp_port
  typesense_url     = data.terraform_remote_state.infra.outputs.typesense_url
  keycloak_url      = data.terraform_remote_state.infra.outputs.keycloak_external_url
  
  # Namespaces
  namespace_staging = data.terraform_remote_state.infra.outputs.namespace_apps_staging
  namespace_prod    = data.terraform_remote_state.infra.outputs.namespace_apps_production
  
  # Environment-specific database names
  db_name_staging = "staging_${var.app_name}"
  db_name_prod    = "production_${var.app_name}"
}

# deployment.tf
resource "kubernetes_deployment" "app_staging" {
  # ... metadata ...
  
  spec {
    template {
      spec {
        container {
          env {
            - name: POSTGRES_HOST
              value: local.postgres_host
            - name: POSTGRES_PORT
              value: tostring(local.postgres_port)
            - name: POSTGRES_DATABASE
              value: local.db_name_staging
            - name: RABBITMQ_HOST
              value: local.rabbitmq_host
            - name: RABBITMQ_VHOST
              value: "staging"
            - name: TYPESENSE_URL
              value: local.typesense_url
          }
        }
      }
    }
  }
}
```

---

## 🔐 Secrets Management

**Create secrets in your application namespace:**

```bash
# PostgreSQL password
kubectl create secret generic postgres-password \
  -n apps-staging \
  --from-literal=password='<pg_password from infrastructure>'

# RabbitMQ password
kubectl create secret generic rabbitmq-password \
  -n apps-staging \
  --from-literal=password='<rabbit_password from infrastructure>'

# Typesense API key
kubectl create secret generic typesense-api-key \
  -n apps-staging \
  --from-literal=api-key='<typesense_api_key from infrastructure>'
```

**Or using Terraform:**

```hcl
resource "kubernetes_secret" "postgres_password" {
  metadata {
    name      = "postgres-password"
    namespace = local.namespace_staging
  }
  
  data = {
    password = var.postgres_password  # Pass from infrastructure outputs
  }
}
```

---

## 🧪 Testing Connectivity

```bash
# Test PostgreSQL
kubectl run -it --rm psql-test --image=postgres:16 --restart=Never -- \
  psql -h postgres.infra-production.svc.cluster.local -U postgres -c '\l'

# Test RabbitMQ
kubectl run -it --rm rabbitmq-test --image=rabbitmq:management --restart=Never -- \
  rabbitmqadmin -H rabbitmq.infra-production.svc.cluster.local -u admin -p PASSWORD list vhosts

# Test Typesense
kubectl run -it --rm curl-test --image=curlimages/curl --restart=Never -- \
  curl http://typesense.infra-production.svc.cluster.local:8108/health
```

---

## 📊 Monitoring

All services expose Prometheus metrics:

```bash
# PostgreSQL metrics
http://postgres.infra-production.svc.cluster.local:9187/metrics

# RabbitMQ metrics
http://rabbitmq.infra-production.svc.cluster.local:15692/metrics

# Check via port-forward
kubectl port-forward -n infra-production svc/postgres 9187:9187
kubectl port-forward -n infra-production svc/rabbitmq 15692:15692
```

---

## ❓ Common Issues

| Issue | Solution |
|-------|----------|
| **Can't connect to postgres** | Check namespace: must connect from within cluster |
| **Database doesn't exist** | Create it first (see Initial Setup above) |
| **RabbitMQ access denied** | Create vhost and set permissions |
| **Typesense 401 error** | Check API key matches infrastructure config |
| **DNS resolution fails** | Ensure full FQDN: `*.infra-production.svc.cluster.local` |

---

## 📚 Additional Resources

- [Full README](../README.md)
- [Infrastructure Outputs](../terraform/outputs.tf)

