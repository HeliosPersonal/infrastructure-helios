# ====================================================================================
# TERRAFORM OUTPUTS
# ====================================================================================
# Exposes connection strings and endpoints for consuming projects
# Projects can use terraform_remote_state to read these values
# ====================================================================================

# ====================================================================================
# NAMESPACE OUTPUTS
# ====================================================================================

output "namespace_infra_staging" {
  value       = kubernetes_namespace.infra_staging.metadata[0].name
  description = "Infrastructure staging namespace name"
}

output "namespace_infra_production" {
  value       = kubernetes_namespace.infra_production.metadata[0].name
  description = "Infrastructure production namespace name"
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

output "postgres_staging_host" {
  value       = "postgres-staging.${kubernetes_namespace.infra_staging.metadata[0].name}.svc.cluster.local"
  description = "PostgreSQL staging internal hostname"
}

output "postgres_staging_port" {
  value       = 5432
  description = "PostgreSQL staging port"
}

output "postgres_staging_database" {
  value       = var.pg_staging_database
  description = "PostgreSQL staging database name"
}

output "postgres_staging_connection_string" {
  value       = "Host=postgres-staging.${kubernetes_namespace.infra_staging.metadata[0].name}.svc.cluster.local;Port=5432;Database=${var.pg_staging_database};Username=postgres"
  description = "PostgreSQL staging connection string (without password)"
  sensitive   = false
}

output "postgres_production_host" {
  value       = "postgres-production.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local"
  description = "PostgreSQL production internal hostname"
}

output "postgres_production_port" {
  value       = 5432
  description = "PostgreSQL production port"
}

output "postgres_production_database" {
  value       = var.pg_production_database
  description = "PostgreSQL production database name"
}

output "postgres_production_connection_string" {
  value       = "Host=postgres-production.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local;Port=5432;Database=${var.pg_production_database};Username=postgres"
  description = "PostgreSQL production connection string (without password)"
  sensitive   = false
}

# ====================================================================================
# RABBITMQ OUTPUTS
# ====================================================================================

output "rabbitmq_staging_host" {
  value       = "rabbitmq-staging.${kubernetes_namespace.infra_staging.metadata[0].name}.svc.cluster.local"
  description = "RabbitMQ staging internal hostname"
}

output "rabbitmq_staging_amqp_port" {
  value       = 5672
  description = "RabbitMQ staging AMQP port"
}

output "rabbitmq_staging_management_port" {
  value       = 15672
  description = "RabbitMQ staging management UI port"
}

output "rabbitmq_staging_connection_string" {
  value       = "amqp://admin@rabbitmq-staging.${kubernetes_namespace.infra_staging.metadata[0].name}.svc.cluster.local:5672"
  description = "RabbitMQ staging connection string (without password)"
  sensitive   = false
}

output "rabbitmq_production_host" {
  value       = "rabbitmq-production.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local"
  description = "RabbitMQ production internal hostname"
}

output "rabbitmq_production_amqp_port" {
  value       = 5672
  description = "RabbitMQ production AMQP port"
}

output "rabbitmq_production_connection_string" {
  value       = "amqp://admin@rabbitmq-production.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local:5672"
  description = "RabbitMQ production connection string (without password)"
  sensitive   = false
}

# ====================================================================================
# TYPESENSE OUTPUTS
# ====================================================================================

output "typesense_staging_host" {
  value       = "typesense.${kubernetes_namespace.infra_staging.metadata[0].name}.svc.cluster.local"
  description = "Typesense staging internal hostname"
}

output "typesense_staging_port" {
  value       = 8108
  description = "Typesense staging port"
}

output "typesense_staging_url" {
  value       = "http://typesense.${kubernetes_namespace.infra_staging.metadata[0].name}.svc.cluster.local:8108"
  description = "Typesense staging URL"
}

output "typesense_production_host" {
  value       = "typesense.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local"
  description = "Typesense production internal hostname"
}

output "typesense_production_port" {
  value       = 8108
  description = "Typesense production port"
}

output "typesense_production_url" {
  value       = "http://typesense.${kubernetes_namespace.infra_production.metadata[0].name}.svc.cluster.local:8108"
  description = "Typesense production URL"
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

