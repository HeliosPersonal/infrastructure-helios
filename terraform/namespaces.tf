# ====================================================================================
# KUBERNETES NAMESPACES
# ====================================================================================
# Defines all Kubernetes namespaces for workload and infrastructure isolation
# Namespaces organize resources into logical groups for staging/production environments
# ====================================================================================

# Application services namespace for staging environment
resource "kubernetes_namespace" "apps_staging" {
  metadata {
    name = "apps-staging"
    labels = {
      environment = "staging"
      layer       = "application"
    }
  }
}

# Infrastructure namespace for production environment (shared databases, message queues, search)
# All infrastructure services run here - applications connect and create their own databases/vhosts/collections
resource "kubernetes_namespace" "infra_production" {
  metadata {
    name = "infra-production"
    labels = {
      environment = "production"
      layer       = "infrastructure"
    }
  }
}

# Application services namespace for production environment
resource "kubernetes_namespace" "apps_production" {
  metadata {
    name = "apps-production"
    labels = {
      environment = "production"
      layer       = "application"
    }
  }
}

# Ingress controller namespace for managing external access to services
resource "kubernetes_namespace" "ingress" {
  metadata {
    name = "ingress"
    labels = {
      layer = "infrastructure"
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Monitoring stack namespace for observability tools (Grafana Alloy, metrics, logs)
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name  = "monitoring"
      layer = "infrastructure"
    }
  }
}
