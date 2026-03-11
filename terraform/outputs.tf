# ====================================================================================
# TERRAFORM OUTPUTS
# ====================================================================================
# Exposes connection strings and endpoints for consuming projects
# Projects can use terraform_remote_state to read these values
# ====================================================================================

# ====================================================================================
# NAMESPACE OUTPUTS
# ====================================================================================

output "namespace_infra_production" {
  value       = kubernetes_namespace.infra_production.metadata[0].name
  description = "Shared infrastructure namespace (all infrastructure services run here)"
}

output "namespace_apps_staging" {
  value       = kubernetes_namespace.apps_staging.metadata[0].name
  description = "Applications staging namespace name"
}

output "namespace_apps_production" {
  value       = kubernetes_namespace.apps_production.metadata[0].name
  description = "Applications production namespace name"
}

# ====================================================================================
# POSTGRESQL OUTPUTS
# ====================================================================================

output "postgres_host" {
  value       = "postgres.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local"
  description = "PostgreSQL shared instance hostname (applications create their own databases)"
}

output "postgres_port" {
  value       = 5432
  description = "PostgreSQL port"
}

output "postgres_connection_string" {
  value       = "Host=postgres.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local;Port=5432;Username=postgres"
  description = "PostgreSQL connection string template (applications specify their own database name)"
  sensitive   = false
}

# ====================================================================================
# RABBITMQ OUTPUTS
# ====================================================================================

output "rabbitmq_host" {
  value       = "rabbitmq.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local"
  description = "RabbitMQ shared instance hostname (applications create their own vhosts)"
}

output "rabbitmq_amqp_port" {
  value       = 5672
  description = "RabbitMQ AMQP port"
}

output "rabbitmq_management_port" {
  value       = 15672
  description = "RabbitMQ management UI port"
}

output "rabbitmq_connection_string" {
  value       = "amqp://admin@rabbitmq.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local:5672"
  description = "RabbitMQ connection string template (applications specify their own vhost)"
  sensitive   = false
}

# ====================================================================================
# TYPESENSE OUTPUTS
# ====================================================================================

output "typesense_host" {
  value       = "typesense.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local"
  description = "Typesense shared instance hostname (applications use collection prefixes for isolation)"
}

output "typesense_port" {
  value       = 8108
  description = "Typesense port"
}

output "typesense_url" {
  value       = "http://typesense.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local:8108"
  description = "Typesense URL"
}

# ====================================================================================
# KEYCLOAK OUTPUTS
# ====================================================================================

output "keycloak_internal_url" {
  value       = "http://keycloak.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local:8080"
  description = "Keycloak internal URL for service-to-service communication"
}

output "keycloak_external_url" {
  value       = "https://${var.keycloak_subdomain}.${var.base_domain}"
  description = "Keycloak external URL for browser/client access"
}

output "keycloak_admin_user" {
  value       = var.keycloak_admin_user
  description = "Keycloak admin username"
}

# ====================================================================================
# REDIS OUTPUTS
# ====================================================================================

output "redis_host" {
  value       = "redis.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local"
  description = "Redis shared instance hostname (applications use key prefixes for isolation)"
}

output "redis_port" {
  value       = 6379
  description = "Redis port"
}

output "redis_connection_string" {
  value       = "redis://redis.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local:6379"
  description = "Redis connection string template (no password — read from secret)"
  sensitive   = false
}

# ====================================================================================
# OLLAMA OUTPUTS
# ====================================================================================

output "ollama_staging_url" {
  value       = var.ollama_enabled ? "http://ollama.${kubernetes_namespace.apps_staging.metadata[0].name}.svc.cluster.local:11434" : ""
  description = "Ollama staging internal URL"
}

# ====================================================================================
# MONITORING OUTPUTS
# ====================================================================================

output "otlp_grpc_endpoint" {
  value       = "grafana-alloy.monitoring.svc.cluster.local:4317"
  description = "OTLP gRPC endpoint for traces and metrics"
}

output "otlp_http_endpoint" {
  value       = "http://grafana-alloy.monitoring.svc.cluster.local:4318"
  description = "OTLP HTTP endpoint for traces and metrics"
}

# ====================================================================================
# DOMAIN OUTPUTS
# ====================================================================================

output "base_domain" {
  value       = var.base_domain
  description = "Base domain for all services"
}

output "internal_domain" {
  value       = var.internal_domain
  description = "Internal domain suffix for local network"
}

