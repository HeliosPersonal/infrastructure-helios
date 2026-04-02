# ====================================================================================
# REDIS CACHE
# ====================================================================================
# Deploys a single shared Redis instance for all environments
# Applications use separate key prefixes (staging:*, production:*) for isolation
# Uses CloudPirates Redis Helm chart with standalone architecture and persistent storage
# ====================================================================================

# Shared Redis instance for all environments
# Applications namespace their keys: staging:<app>:<key>, production:<app>:<key>
resource "helm_release" "redis" {
  name             = "redis"
  namespace        = kubernetes_namespace.infra_production.metadata[0].name
  repository       = "oci://registry-1.docker.io/cloudpirates"
  chart            = "redis"
  version          = "0.26.8"
  create_namespace = false

  depends_on = [kubernetes_namespace.infra_production]

  # Single-master standalone (no replicas) — fits home-lab resource profile
  set {
    name  = "architecture"
    value = "standalone"
  }

  # Authentication
  set {
    name  = "auth.enabled"
    value = "true"
  }

  set_sensitive {
    name  = "auth.password"
    value = var.redis_password
  }

  # Persistent storage for AOF / RDB snapshots
  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.size"
    value = var.redis_storage_size
  }

  set {
    name  = "persistence.storageClass"
    value = var.redis_storage_class
  }

  # Predictable service name: redis.<namespace>.svc.cluster.local
  set {
    name  = "fullnameOverride"
    value = "redis"
  }

  # Enable Prometheus metrics sidecar
  set {
    name  = "metrics.enabled"
    value = "true"
  }

  # ServiceMonitor disabled — Prometheus Operator CRDs not present in this cluster
  # Metrics are still exposed on port 9121 and scraped via Alloy / annotation-based discovery
  set {
    name  = "metrics.serviceMonitor.enabled"
    value = "false"
  }

  # Resource limits — Redis is lightweight but must be bounded on a shared node
  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "resources.limits.memory"
    value = "512Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "300m"
  }
}

# ====================================================================================
# REDIS INSIGHT UI
# ====================================================================================
# Redis Insight v2 — browser-based GUI for inspecting keys, running commands,
# monitoring memory, and managing Redis connections.
# Accessible at https://redisinsight.<base_domain>
# On first launch, add a connection:
#   Name:     Helios
#   Host:     redis.infra-production.svc.cluster.local
#   Port:     6379
#   Password: (from redis_password secret)
# ====================================================================================

resource "kubernetes_deployment" "redis_insight" {
  count      = var.redis_insight_enabled ? 1 : 0
  depends_on = [kubernetes_namespace.infra_production, helm_release.redis]

  metadata {
    name      = "redis-insight"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
    labels = {
      app = "redis-insight"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "redis-insight"
      }
    }

    template {
      metadata {
        labels = {
          app = "redis-insight"
        }
      }

      spec {
        container {
          name  = "redis-insight"
          image = "redis/redisinsight:3.2"

          port {
            container_port = 5540
            name           = "http"
          }

          # Persist connection configurations so they survive pod restarts
          volume_mount {
            name       = "data"
            mount_path = "/data"
          }

          liveness_probe {
            http_get {
              path = "/api/health/"
              port = 5540
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/api/health/"
              port = 5540
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.redis_insight[0].metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "redis_insight" {
  count      = var.redis_insight_enabled ? 1 : 0
  depends_on = [kubernetes_namespace.infra_production]

  # local-path uses WaitForFirstConsumer binding — the PVC will only reach Bound
  # once a pod mounts it. Setting wait_until_bound = false prevents Terraform from
  # blocking here until the deployment brings up the pod.
  wait_until_bound = false

  metadata {
    name      = "redis-insight-data"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "local-path"

    resources {
      requests = {
        storage = "256Mi"
      }
    }
  }
}

resource "kubernetes_service" "redis_insight" {
  count      = var.redis_insight_enabled ? 1 : 0
  depends_on = [kubernetes_namespace.infra_production]

  metadata {
    name      = "redis-insight"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
  }

  spec {
    selector = {
      app = "redis-insight"
    }

    port {
      port        = 5540
      target_port = 5540
      name        = "http"
    }
  }
}

