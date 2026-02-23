# ====================================================================================
# DATA SOURCE - SHARED INFRASTRUCTURE
# ====================================================================================
# Reads outputs from infrastructure-helios via Kubernetes backend remote state
# ====================================================================================

data "terraform_remote_state" "infra" {
  backend = "kubernetes"
  
  config = {
    secret_suffix = "infrastructure-helios"
    namespace     = "kube-system"
    config_path   = var.kubeconfig_path
  }
}

# ====================================================================================
# LOCAL VALUES FROM SHARED INFRASTRUCTURE
# ====================================================================================

locals {
  # Namespaces
  namespace_apps_staging    = data.terraform_remote_state.infra.outputs.namespace_apps_staging
  namespace_apps_production = data.terraform_remote_state.infra.outputs.namespace_apps_production
  
  # PostgreSQL - Shared instance (same host for all environments)
  # Applications create their own databases: staging_<appname>, production_<appname>
  postgres_host              = data.terraform_remote_state.infra.outputs.postgres_host
  postgres_port              = data.terraform_remote_state.infra.outputs.postgres_port
  postgres_connection_string = data.terraform_remote_state.infra.outputs.postgres_connection_string
  
  # RabbitMQ - Shared instance (same host for all environments)
  # Applications create their own vhosts: staging, production, or staging-<appname>
  rabbitmq_host              = data.terraform_remote_state.infra.outputs.rabbitmq_host
  rabbitmq_amqp_port         = data.terraform_remote_state.infra.outputs.rabbitmq_amqp_port
  rabbitmq_management_port   = data.terraform_remote_state.infra.outputs.rabbitmq_management_port
  rabbitmq_connection_string = data.terraform_remote_state.infra.outputs.rabbitmq_connection_string
  
  # Typesense - Shared instance (same host for all environments)
  # Applications use collection prefixes: staging_<appname>_*, production_<appname>_*
  typesense_url  = data.terraform_remote_state.infra.outputs.typesense_url
  typesense_host = data.terraform_remote_state.infra.outputs.typesense_host
  typesense_port = data.terraform_remote_state.infra.outputs.typesense_port
  
  # Keycloak
  keycloak_internal_url = data.terraform_remote_state.infra.outputs.keycloak_internal_url
  keycloak_external_url = data.terraform_remote_state.infra.outputs.keycloak_external_url
  
  # Monitoring
  otlp_grpc_endpoint = data.terraform_remote_state.infra.outputs.otlp_grpc_endpoint
  otlp_http_endpoint = data.terraform_remote_state.infra.outputs.otlp_http_endpoint
  
  # Ollama
  ollama_staging_url = data.terraform_remote_state.infra.outputs.ollama_staging_url
  
  # Domains
  base_domain     = data.terraform_remote_state.infra.outputs.base_domain
  internal_domain = data.terraform_remote_state.infra.outputs.internal_domain
}

