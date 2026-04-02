# ====================================================================================
# POSTGRESQL DATABASE
# ====================================================================================
# Deploys a single shared PostgreSQL instance for all environments
# Applications create their own databases within this instance
# Uses Bitnami PostgreSQL Helm chart with persistent storage
# ====================================================================================

# Shared PostgreSQL instance for all environments
# Applications connect and create their own databases (staging_*, production_*)
resource "helm_release" "postgres" {
  name             = "postgres"
  namespace        = kubernetes_namespace.infra_production.metadata[0].name
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "postgresql"
  version          = "18.5.14"
  create_namespace = false

  depends_on = [kubernetes_namespace.infra_production]

  # Database authentication - single admin password for all access
  set_sensitive {
    name  = "auth.postgresPassword"
    value = var.pg_password
  }

  set {
    name  = "auth.username"
    value = "postgres"
  }

  set {
    name  = "auth.database"
    value = "postgres"
  }

  # Persistent storage configuration
  set {
    name  = "primary.persistence.size"
    value = var.pg_storage_size
  }

  set {
    name  = "primary.persistence.storageClass"
    value = var.pg_storage_class
  }

  set {
    name  = "fullnameOverride"
    value = "postgres"
  }

  # Enable metrics for monitoring
  set {
    name  = "metrics.enabled"
    value = "true"
  }

  # Resource limits — shared instance for all environments
  set {
    name  = "primary.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "primary.resources.requests.cpu"
    value = "250m"
  }

  set {
    name  = "primary.resources.limits.memory"
    value = "1Gi"
  }

  set {
    name  = "primary.resources.limits.cpu"
    value = "1000m"
  }
}

