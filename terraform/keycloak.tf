# ====================================================================================
# KEYCLOAK - Identity and Access Management
# ====================================================================================
# Deploys Keycloak authentication server for user management and SSO
# Includes embedded PostgreSQL database for Keycloak data storage
# ====================================================================================

locals {
  keycloak_hostname = "${var.keycloak_subdomain}.${var.base_domain}"
}

# Keycloak authentication server for production environment
# Provides OAuth2/OIDC authentication, user management, and SSO capabilities
resource "helm_release" "keycloak" {
  name             = "keycloak"
  namespace        = kubernetes_namespace.infra_production.metadata[0].name
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "keycloak"
  create_namespace = false

  depends_on = [kubernetes_namespace.infra_production]

  # Admin user configuration
  set {
    name  = "auth.adminUser"
    value = var.keycloak_admin_user
  }

  set_sensitive {
    name  = "auth.adminPassword"
    value = var.keycloak_admin_password
  }

  # Embedded PostgreSQL database for Keycloak data persistence
  set {
    name  = "postgresql.enabled"
    value = "true"
  }

  set {
    name  = "postgresql.auth.database"
    value = "keycloak"
  }

  set {
    name  = "postgresql.auth.username"
    value = "postgres"
  }

  set_sensitive {
    name  = "postgresql.auth.password"
    value = var.keycloak_postgres_password
  }

  # Enable Prometheus metrics endpoint for monitoring
  set {
    name  = "metrics.enabled"
    value = "true"
  }

  # Production mode configuration
  set {
    name  = "production"
    value = "true"
  }

  # Public hostname configuration (sets both frontend and admin URLs)
  set {
    name  = "extraEnvVars[0].name"
    value = "KC_HOSTNAME"
  }

  set {
    name  = "extraEnvVars[0].value"
    value = local.keycloak_hostname
  }

  # Disable strict hostname checking for flexible resolution
  set {
    name  = "extraEnvVars[1].name"
    value = "KC_HOSTNAME_STRICT"
  }

  set {
    name  = "extraEnvVars[1].value"
    value = "false"
  }

  # Trust X-Forwarded-* headers from nginx ingress controller
  set {
    name  = "proxy"
    value = "edge"
  }
}

