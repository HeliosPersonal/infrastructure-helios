# ====================================================================================
# CLOUDFLARE DYNAMIC DNS (DDNS)
# ====================================================================================
# Automatically updates Cloudflare DNS records with current public IP address
# Essential for home lab/self-hosted environments with dynamic IP from ISP
# 
# Uses dynamic resource creation based on ddns_subdomains variable
# ====================================================================================

# Cloudflare API token stored as Kubernetes secret
# Used by DDNS container to authenticate with Cloudflare API
resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = "kube-system"
  }

  data = {
    api-token = var.cloudflare_api_token
  }

  type = "Opaque"
}

# Dynamic DDNS deployments for each subdomain
resource "kubernetes_deployment" "cloudflare_ddns" {
  for_each   = toset(var.ddns_subdomains)
  depends_on = [kubernetes_secret.cloudflare_api_token]

  metadata {
    name      = "cloudflare-ddns-${each.key}"
    namespace = "kube-system"
    labels = {
      app       = "cloudflare-ddns"
      subdomain = each.key
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app       = "cloudflare-ddns"
        subdomain = each.key
      }
    }

    template {
      metadata {
        labels = {
          app       = "cloudflare-ddns"
          subdomain = each.key
        }
      }

      spec {
        container {
          name  = "cloudflare-ddns"
          image = "oznu/cloudflare-ddns:latest"

          env {
            name = "API_KEY"
            value_from {
              secret_key_ref {
                name = "cloudflare-api-token"
                key  = "api-token"
              }
            }
          }

          env {
            name  = "ZONE"
            value = var.base_domain
          }

          env {
            name  = "SUBDOMAIN"
            value = each.key
          }

          env {
            name  = "PROXIED"
            value = "true"
          }

          resources {
            limits = {
              cpu    = "50m"
              memory = "64Mi"
            }
            requests = {
              cpu    = "10m"
              memory = "32Mi"
            }
          }
        }
      }
    }
  }
}

