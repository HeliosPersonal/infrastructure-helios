# ====================================================================================
# TYPESENSE SEARCH ENGINE
# ====================================================================================
# Deploys a single shared Typesense instance for all environments
# Applications create their own collections with prefixes (staging_*, production_*)
# Includes StatefulSet, Service, and Dashboard UI
# ====================================================================================

# Shared Typesense StatefulSet for all environments
# Applications use separate API keys and collection naming conventions
resource "kubernetes_stateful_set" "typesense" {
  depends_on = [kubernetes_namespace.infra_production]

  metadata {
    name      = "typesense"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
  }

  spec {
    service_name = "typesense"
    replicas     = 1

    selector {
      match_labels = {
        app = "typesense"
      }
    }

    template {
      metadata {
        labels = {
          app = "typesense"
        }
      }

      spec {
        container {
          name  = "typesense"
          image = "typesense/typesense:30.1"

          env {
            name  = "TYPESENSE_DATA_DIR"
            value = "/data"
          }

          env {
            name  = "TYPESENSE_API_KEY"
            value = var.typesense_api_key
          }

          env {
            name  = "TYPESENSE_ENABLE_CORS"
            value = "true"
          }

          port {
            container_port = 8108
            name           = "http"
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8108
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8108
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          startup_probe {
            http_get {
              path = "/health"
              port = 8108
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 12
          }

          resources {
            requests = {
              memory = "512Mi"
              cpu    = "500m"
            }
            limits = {
              memory = "2Gi"
              cpu    = "2000m"
            }
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "local-path"

        resources {
          requests = {
            storage = var.typesense_storage_size
          }
        }
      }
    }
  }
}

# Typesense Service - headless for StatefulSet
resource "kubernetes_service" "typesense" {
  metadata {
    name      = "typesense"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
  }

  spec {
    selector = {
      app = "typesense"
    }

    port {
      port        = 8108
      target_port = 8108
      name        = "http"
    }

    cluster_ip = "None"
  }
}

# Typesense Dashboard UI - web interface for managing collections
resource "kubernetes_deployment" "typesense_dashboard" {
  depends_on = [kubernetes_namespace.infra_production]

  metadata {
    name      = "typesense-dashboard"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "typesense-dashboard"
      }
    }

    template {
      metadata {
        labels = {
          app = "typesense-dashboard"
        }
      }

      spec {
        container {
          name  = "dashboard"
          image = "ghcr.io/bfritscher/typesense-dashboard:latest"

          port {
            container_port = 80
            name           = "http"
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "100m"
            }
          }
        }
      }
    }
  }
}

# Typesense Dashboard Service
resource "kubernetes_service" "typesense_dashboard" {
  metadata {
    name      = "typesense-dashboard"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
  }

  spec {
    selector = {
      app = "typesense-dashboard"
    }

    port {
      port        = 80
      target_port = 80
      name        = "http"
    }

    type = "ClusterIP"
  }
}

