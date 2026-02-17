# Infrastructure Helios

Shared Kubernetes infrastructure managed by Terraform. This repository provides the base infrastructure that can be consumed by multiple projects.

## Components

| Component | Description |
|-----------|-------------|
| **PostgreSQL** | Database for staging and production |
| **RabbitMQ** | Message broker for staging and production |
| **Keycloak** | Identity and access management (SSO, OAuth2/OIDC) |
| **Typesense** | Search engine with dashboard UI |
| **Ollama** | Local LLM inference service |
| **cert-manager** | Automated TLS certificate management |
| **NGINX Ingress** | Ingress controller for external access |
| **Grafana Alloy** | Observability agent (metrics, logs, traces) |
| **Cloudflare DDNS** | Dynamic DNS updates |

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.5
- [kubectl](https://kubernetes.io/docs/tasks/tools/) configured with cluster access
- [Helm](https://helm.sh/docs/intro/install/) >= 3.0
- Access to Kubernetes cluster (kubeconfig)

## Quick Start

### 1. Clone and Configure

```bash
cd terraform

# Copy example variables
cp terraform.tfvars.example terraform.tfvars
cp terraform.tfvars.example terraform.secret.tfvars

# Edit with your values
vim terraform.tfvars
vim terraform.secret.tfvars
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan and Apply

```bash
terraform plan \
  -var-file="terraform.tfvars" \
  -var-file="terraform.secret.tfvars"

terraform apply \
  -var-file="terraform.tfvars" \
  -var-file="terraform.secret.tfvars"
```

## State Management

State is stored in a Kubernetes secret in the `kube-system` namespace:

```bash
# View state secret
kubectl get secret -n kube-system -l "app.kubernetes.io/name=terraform-state"
```

## Using Outputs in Other Projects

Projects can consume this infrastructure by reading the Terraform remote state:

```hcl
# In your project's Terraform
data "terraform_remote_state" "infra" {
  backend = "kubernetes"
  
  config = {
    secret_suffix = "infrastructure-helios"
    namespace     = "kube-system"
    config_path   = "~/.kube/config"
  }
}

# Use outputs
locals {
  postgres_host = data.terraform_remote_state.infra.outputs.postgres_staging_host
  rabbitmq_host = data.terraform_remote_state.infra.outputs.rabbitmq_staging_host
  keycloak_url  = data.terraform_remote_state.infra.outputs.keycloak_external_url
  otlp_endpoint = data.terraform_remote_state.infra.outputs.otlp_grpc_endpoint
}
```

## Available Outputs

### Namespaces
- `namespace_infra_staging` - Infrastructure staging namespace
- `namespace_infra_production` - Infrastructure production namespace
- `namespace_apps_staging` - Applications staging namespace
- `namespace_apps_production` - Applications production namespace

### PostgreSQL
- `postgres_staging_host` - Staging database hostname
- `postgres_staging_connection_string` - Staging connection string (without password)
- `postgres_production_host` - Production database hostname
- `postgres_production_connection_string` - Production connection string (without password)

### RabbitMQ
- `rabbitmq_staging_host` - Staging message broker hostname
- `rabbitmq_staging_connection_string` - Staging AMQP URL (without password)
- `rabbitmq_production_host` - Production message broker hostname
- `rabbitmq_production_connection_string` - Production AMQP URL (without password)

### Typesense
- `typesense_staging_url` - Staging search engine URL
- `typesense_production_url` - Production search engine URL

### Keycloak
- `keycloak_internal_url` - Internal URL for service-to-service auth
- `keycloak_external_url` - External URL for browser/client access

### Monitoring
- `otlp_grpc_endpoint` - OTLP gRPC endpoint for traces/metrics
- `otlp_http_endpoint` - OTLP HTTP endpoint for traces/metrics

### Ollama
- `ollama_staging_url` - LLM inference service URL

## Directory Structure

```
infrastructure-helios/
├── terraform/
│   ├── provider.tf          # Providers + K8s backend
│   ├── variables.tf          # All configurable variables
│   ├── outputs.tf            # Outputs for consuming projects
│   ├── namespaces.tf         # K8s namespaces
│   ├── postgres.tf           # PostgreSQL databases
│   ├── rabbitmq.tf           # RabbitMQ message brokers
│   ├── keycloak.tf           # Identity management
│   ├── typesense.tf          # Search engine
│   ├── ollama.tf             # LLM service
│   ├── cert-manager.tf       # TLS certificates
│   ├── ingress.tf            # NGINX ingress + routes
│   ├── monitoring.tf         # Grafana Alloy stack
│   ├── ddns.tf               # Cloudflare DDNS
│   ├── terraform.tfvars.example
│   └── values/
│       └── alloy-values.yaml # Grafana Alloy Helm values
├── .gitignore
└── README.md
```

## Customization

### Domains

All domains are configurable via variables:

```hcl
base_domain        = "mycompany.com"      # External domain
internal_domain    = "local"               # Internal network suffix
keycloak_subdomain = "auth"                # -> auth.mycompany.com
ddns_subdomains    = ["www", "api", "auth"]
```

### Disabling Components

```hcl
# Disable Ollama if not needed
ollama_enabled = false
```

## Common Operations

### View Current State
```bash
terraform state list
terraform state show helm_release.postgres_staging
```

### Target Specific Resource
```bash
terraform apply \
  -var-file="terraform.tfvars" \
  -var-file="terraform.secret.tfvars" \
  -target=helm_release.postgres_staging
```

### Import Existing Resource
```bash
terraform import kubernetes_namespace.apps_staging apps-staging
```

## License

MIT

