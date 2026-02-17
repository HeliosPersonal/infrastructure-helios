# ====================================================================================
# EXAMPLE: Project-Specific Infrastructure
# ====================================================================================
# This shows how a project (like overflow) can use shared infrastructure outputs
# and add its own project-specific resources
# ====================================================================================

terraform {
  required_version = ">= 1.5"

  backend "kubernetes" {
    secret_suffix = "overflow"  # Project-specific state
    namespace     = "kube-system"
    config_path   = "~/.kube/config"
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
    POSTGRES_HOST     = local.postgres_staging_host
    RABBITMQ_HOST     = local.rabbitmq_staging_host
    TYPESENSE_URL     = local.typesense_staging_url
    KEYCLOAK_URL      = local.keycloak_external_url
    KEYCLOAK_INTERNAL = local.keycloak_internal_url
    OTLP_ENDPOINT     = local.otlp_grpc_endpoint
    OLLAMA_URL        = local.ollama_staging_url
  }
}

# ====================================================================================
# EXAMPLE: Project-specific ingress using shared domain
# ====================================================================================

resource "kubernetes_ingress_v1" "overflow_staging" {
  metadata {
    name      = "overflow-staging"
    namespace = local.namespace_apps_staging
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-production"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["staging.${local.base_domain}"]
      secret_name = "overflow-staging-tls"
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

