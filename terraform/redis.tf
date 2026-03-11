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
  version          = "0.26.4"
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
}
