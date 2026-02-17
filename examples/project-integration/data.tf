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
  
  # PostgreSQL
  postgres_staging_host              = data.terraform_remote_state.infra.outputs.postgres_staging_host
  postgres_staging_connection_string = data.terraform_remote_state.infra.outputs.postgres_staging_connection_string
  postgres_production_host           = data.terraform_remote_state.infra.outputs.postgres_production_host
  
  # RabbitMQ
  rabbitmq_staging_host              = data.terraform_remote_state.infra.outputs.rabbitmq_staging_host
  rabbitmq_staging_connection_string = data.terraform_remote_state.infra.outputs.rabbitmq_staging_connection_string
  rabbitmq_production_host           = data.terraform_remote_state.infra.outputs.rabbitmq_production_host
  
  # Typesense
  typesense_staging_url    = data.terraform_remote_state.infra.outputs.typesense_staging_url
  typesense_production_url = data.terraform_remote_state.infra.outputs.typesense_production_url
  
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

