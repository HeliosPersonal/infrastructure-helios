# ========================================
# INGRESS CONFIGURATION
# ========================================
# This file manages:
# 1. NGINX Ingress Controller installation
# 2. Infrastructure service ingress rules (RabbitMQ, Typesense, Keycloak)
#
# Application service ingresses are managed separately in project repos
# via Kustomize or project-specific Terraform.
# ========================================

locals {
  keycloak_host            = "${var.keycloak_subdomain}.${var.base_domain}"
  rabbitmq_host            = "rabbit.${var.base_domain}"
  typesense_dashboard_host = "typesense.${var.base_domain}"
  typesense_api_host       = "typesense-api.${var.base_domain}"
  redis_insight_host       = "redisinsight.${var.base_domain}"
}

############################
# INGRESS CONTROLLER
############################
# Deploys NGINX Ingress Controller to handle all ingress traffic.
# This is a cluster-wide component that routes external traffic to services.

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  namespace        = kubernetes_namespace.ingress.metadata[0].name
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.14.0"
  create_namespace = false

  set {
    name  = "controller.config.ssl-redirect"
    value = "true"
  }

  set {
    name  = "controller.config.force-ssl-redirect"
    value = "true"
  }
}

resource "kubernetes_secret_v1" "cloudflare_origin" {
  metadata {
    name      = "cloudflare-origin"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
  }

  type = "kubernetes.io/tls"

  binary_data = {
    "tls.crt" = filebase64("${path.module}/certs/origin.crt")
    "tls.key" = filebase64("${path.module}/certs/origin.key")
  }

  depends_on = [kubernetes_namespace.infra_production]
}

############################
# KEYCLOAK INGRESS (GLOBAL)
############################
# Exposes Keycloak authentication service for the entire cluster.
# Used by both staging and production environments.

resource "kubernetes_ingress_v1" "keycloak_global" {
  depends_on = [kubernetes_namespace.infra_production, helm_release.ingress_nginx, helm_release.keycloak, kubernetes_secret_v1.cloudflare_origin]

  metadata {
    name      = "keycloak-global"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
    labels = {
      app = "keycloak"
    }
    annotations = {
      # SSL/TLS handled by Cloudflare - no cert-manager needed
      "nginx.ingress.kubernetes.io/proxy-buffer-size"       = "128k"
      "nginx.ingress.kubernetes.io/proxy-buffers-number"    = "4"
      "nginx.ingress.kubernetes.io/proxy-busy-buffers-size" = "256k"
      "nginx.ingress.kubernetes.io/backend-protocol"        = "HTTP"
      "nginx.ingress.kubernetes.io/upstream-vhost"          = "$host"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      secret_name = kubernetes_secret_v1.cloudflare_origin.metadata[0].name
      hosts       = [local.keycloak_host]
    }

    rule {
      host = local.keycloak_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "keycloak"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }

  }
}

############################
# INFRASTRUCTURE INGRESSES
############################
# Exposes management UIs and APIs for shared infrastructure services

# RabbitMQ Management UI
resource "kubernetes_ingress_v1" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      secret_name = kubernetes_secret_v1.cloudflare_origin.metadata[0].name
      hosts       = [local.rabbitmq_host]
    }

    rule {
      host = local.rabbitmq_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "rabbitmq"
              port {
                number = 15672
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.infra_production, helm_release.rabbitmq, helm_release.ingress_nginx, kubernetes_secret_v1.cloudflare_origin]
}

# Typesense Dashboard UI
resource "kubernetes_ingress_v1" "typesense_dashboard" {
  metadata {
    name      = "typesense-dashboard"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      secret_name = kubernetes_secret_v1.cloudflare_origin.metadata[0].name
      hosts       = [local.typesense_dashboard_host]
    }

    rule {
      host = local.typesense_dashboard_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "typesense-dashboard"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.typesense_dashboard, kubernetes_secret_v1.cloudflare_origin]
}

# Typesense API endpoint
resource "kubernetes_ingress_v1" "typesense_api" {
  metadata {
    name      = "typesense-api"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/cors-allow-origin"  = "*"
      "nginx.ingress.kubernetes.io/cors-allow-methods" = "GET, POST, PUT, DELETE, OPTIONS"
      "nginx.ingress.kubernetes.io/cors-allow-headers" = "DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization,X-TYPESENSE-API-KEY"
      "nginx.ingress.kubernetes.io/enable-cors"        = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      secret_name = kubernetes_secret_v1.cloudflare_origin.metadata[0].name
      hosts       = [local.typesense_api_host]
    }

    rule {
      host = local.typesense_api_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "typesense"
              port {
                number = 8108
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.infra_production, kubernetes_stateful_set.typesense, helm_release.ingress_nginx, kubernetes_secret_v1.cloudflare_origin]
}

# Redis Insight UI
resource "kubernetes_ingress_v1" "redis_insight" {
  count = var.redis_insight_enabled ? 1 : 0

  metadata {
    name      = "redis-insight"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
    annotations = {
      # Increase proxy timeouts for long-running Redis commands in the browser
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "3600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "3600"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      secret_name = kubernetes_secret_v1.cloudflare_origin.metadata[0].name
      hosts       = [local.redis_insight_host]
    }

    rule {
      host = local.redis_insight_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "redis-insight"
              port {
                number = 5540
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.redis_insight, helm_release.ingress_nginx, kubernetes_secret_v1.cloudflare_origin]
}

