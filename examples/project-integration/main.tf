# ====================================================================================
# EXAMPLE: Project-Specific Infrastructure
# ====================================================================================
# This shows how a project (like overflow) can use shared infrastructure outputs
# and add its own project-specific resources
# ====================================================================================

terraform {
  required_version = ">= 1.5"

  backend "azurerm" {
    resource_group_name  = "rg-helios-tfstate"
    storage_account_name = "stheliosinfrastate"
    container_name       = "tfstate"
    key                  = "overflow.tfstate"
    use_azuread_auth     = true
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# ====================================================================================
# EXAMPLE: ConfigMap with connection strings from shared infrastructure
# ====================================================================================

resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "overflow-config"
    namespace = local.namespace_apps_staging
  }

  data = {
    # Shared PostgreSQL - specify your own database name
    POSTGRES_HOST     = local.postgres_host
    POSTGRES_PORT     = tostring(local.postgres_port)
    POSTGRES_DATABASE = "staging_overflow"  # Apps create their own databases
    
    # Shared RabbitMQ - specify your own vhost
    RABBITMQ_HOST     = local.rabbitmq_host
    RABBITMQ_PORT     = tostring(local.rabbitmq_amqp_port)
    RABBITMQ_VHOST    = "staging"  # or "staging-overflow" for isolation
    
    # Shared Typesense - use collection prefixes
    TYPESENSE_URL            = local.typesense_url
    TYPESENSE_COLLECTION_PREFIX = "staging_overflow_"  # e.g., staging_overflow_questions

    # Shared Redis - use key prefixes for isolation
    REDIS_HOST   = local.redis_host
    REDIS_PORT   = tostring(local.redis_port)
    REDIS_PREFIX = "staging:overflow:"  # e.g., staging:overflow:session:<id>

    # Keycloak
    KEYCLOAK_URL      = local.keycloak_external_url
    KEYCLOAK_INTERNAL = local.keycloak_internal_url
    
    # Monitoring
    OTLP_ENDPOINT     = local.otlp_grpc_endpoint
    
    # Ollama
    OLLAMA_URL        = local.ollama_url
  }
}

# ====================================================================================
# EXAMPLE: Project-specific ingress using shared domain
# ====================================================================================
# TLS is terminated by Cloudflare; the origin certificate secret must be created
# in each namespace that needs TLS ingress (see cloudflare-origin secret in infra).
# ====================================================================================

resource "kubernetes_ingress_v1" "overflow_staging" {
  metadata {
    name      = "overflow-staging"
    namespace = local.namespace_apps_staging
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["staging.${local.base_domain}"]
      secret_name = "cloudflare-origin"
    }

    rule {
      host = "staging.${local.base_domain}"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "overflow-web"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

