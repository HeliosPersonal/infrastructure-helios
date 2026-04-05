# ====================================================================================
# CLOUDFLARE TUNNEL (cloudflared)
# ====================================================================================
# Deploys cloudflared as a Kubernetes Deployment to establish an outbound tunnel
# to Cloudflare's edge network — replacing the need for router port forwarding.
#
# Traffic routing:
#   *.<base_domain>  → nginx ingress controller (in-cluster, port 80)
#
# Auth: tunnel token (no cert file). Token is generated from the Cloudflare
# Zero Trust dashboard (Networks → Tunnels → Create tunnel → Docker).
# ====================================================================================

# Tunnel token stored as a Kubernetes Secret
resource "kubernetes_secret_v1" "cloudflared_tunnel_token" {
  count = var.cloudflared_enabled ? 1 : 0

  metadata {
    name      = "cloudflared-tunnel-token"
    namespace = kubernetes_namespace.ingress.metadata[0].name
    labels = {
      app = "cloudflared"
    }
  }

  type = "Opaque"

  data = {
    token = var.cloudflare_tunnel_token
  }
}

# cloudflared ingress routing config
# With token-based auth, NO `tunnel:` or `credentials-file:` keys are needed.
resource "kubernetes_config_map_v1" "cloudflared_config" {
  count = var.cloudflared_enabled ? 1 : 0

  metadata {
    name      = "cloudflared-config"
    namespace = kubernetes_namespace.ingress.metadata[0].name
    labels = {
      app = "cloudflared"
    }
  }

  data = {
    "config.yaml" = yamlencode({
      ingress = [
        # All subdomains → nginx ingress (HTTP, Cloudflare terminates TLS)
        {
          hostname = "*.${var.base_domain}"
          service  = "http://ingress-nginx-controller.${kubernetes_namespace.ingress.metadata[0].name}.svc.cluster.local:80"
        },
        # Required catch-all rule (must be last)
        {
          service = "http_status:404"
        }
      ]
    })
  }
}

# cloudflared Deployment — 2 replicas for HA (each connects independently)
resource "kubernetes_deployment_v1" "cloudflared" {
  count = var.cloudflared_enabled ? 1 : 0

  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace.ingress.metadata[0].name
    labels = {
      app = "cloudflared"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "cloudflared"
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
        annotations = {
          # Force pod restart when config changes
          "checksum/config" = sha256(kubernetes_config_map_v1.cloudflared_config[0].data["config.yaml"])
        }
      }

      spec {
        # Spread replicas across nodes (no-op on single node but good practice)
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "kubernetes.io/hostname"
          when_unsatisfiable = "DoNotSchedule"
          label_selector {
            match_labels = {
              app = "cloudflared"
            }
          }
        }

        container {
          name  = "cloudflared"
          image = "cloudflare/cloudflared:${var.cloudflared_image_tag}"

          # `run` reads ingress from config.yaml; TUNNEL_TOKEN authenticates
          args = [
            "tunnel",
            "--config", "/etc/cloudflared/config.yaml",
            "--metrics", "0.0.0.0:2000",
            "run",
          ]

          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.cloudflared_tunnel_token[0].metadata[0].name
                key  = "token"
              }
            }
          }

          port {
            name           = "metrics"
            container_port = 2000
            protocol       = "TCP"
          }

          # /ready returns 200 once the tunnel is established
          liveness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 3
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/cloudflared"
            read_only  = true
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = 65532 # nonroot
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.cloudflared_config[0].metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.ingress,
    helm_release.ingress_nginx,
    kubernetes_secret_v1.cloudflared_tunnel_token,
    kubernetes_config_map_v1.cloudflared_config,
  ]
}

