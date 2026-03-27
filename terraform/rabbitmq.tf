# ====================================================================================
# RABBITMQ MESSAGE BROKER
# ====================================================================================
# Deploys a single shared RabbitMQ instance for all environments
# Applications create their own vhosts and users within this instance
# Handles asynchronous messaging between microservices
# ====================================================================================

# Shared RabbitMQ instance for all environments
# Applications create separate vhosts for staging/production isolation
resource "helm_release" "rabbitmq" {
  name       = "rabbitmq"
  namespace  = kubernetes_namespace.infra_production.metadata[0].name
  repository = "oci://registry-1.docker.io/cloudpirates"
  chart      = "rabbitmq"

  depends_on = [kubernetes_namespace.infra_production]

  # Admin authentication for management
  set {
    name  = "auth.username"
    value = "admin"
  }

  set_sensitive {
    name  = "auth.password"
    value = var.rabbit_password
  }

  # Persistent storage for message queues
  set {
    name  = "persistence.size"
    value = var.rabbit_persistence_size
  }

  # Enable shovel plugin for moving/forwarding messages between brokers or queues
  set {
    name  = "extraPlugins"
    value = "rabbitmq_shovel rabbitmq_shovel_management"
  }
}

