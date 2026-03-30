# ====================================================================================
# TERRAFORM VARIABLES
# ====================================================================================
# Variable definitions for configurable infrastructure parameters
# Actual values are set in terraform.tfvars and terraform.secret.tfvars
# ====================================================================================

# ====================================================================================
# GENERAL CONFIGURATION
# ====================================================================================

variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/config"
  description = "Path to kubeconfig for k3s cluster."
}

variable "enable_typesense_clusters" {
  type        = bool
  default     = false
  description = "Create TypesenseCluster resources (set to true only after the CRD is installed)."
}

# ====================================================================================
# DOMAIN CONFIGURATION
# ====================================================================================

variable "base_domain" {
  type        = string
  description = "Base domain for all services (e.g., devoverflow.org)"
}

variable "internal_domain" {
  type        = string
  default     = "helios"
  description = "Internal domain suffix for local network access (e.g., helios)"
}

variable "keycloak_subdomain" {
  type        = string
  default     = "keycloak"
  description = "Subdomain for Keycloak (e.g., keycloak -> keycloak.devoverflow.org)"
}

variable "ddns_subdomains" {
  type        = list(string)
  default     = ["www", "staging", "keycloak", "k8s"]
  description = "List of subdomains to configure DDNS for"
}

# ====================================================================================
# CLOUDFLARE CONFIGURATION
# ====================================================================================

variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token for DDNS updates"
}


# ====================================================================================
# POSTGRESQL CONFIGURATION
# ====================================================================================

variable "pg_password" {
  type        = string
  sensitive   = true
  description = "PostgreSQL admin password for shared instance"
}

variable "pg_storage_size" {
  type        = string
  default     = "20Gi"
  description = "Persistent volume size for PostgreSQL (increased for shared instance)"
}

variable "pg_storage_class" {
  type        = string
  default     = "local-path"
  description = "Storage class for PostgreSQL persistent volumes"
}

# ====================================================================================
# RABBITMQ CONFIGURATION
# ====================================================================================

variable "rabbit_password" {
  type        = string
  sensitive   = true
  description = "RabbitMQ admin password for shared instance"
}

variable "rabbit_persistence_size" {
  type        = string
  default     = "8Gi"
  description = "Persistent volume size for RabbitMQ (increased for shared instance)"
}

# ====================================================================================
# TYPESENSE CONFIGURATION
# ====================================================================================

variable "typesense_api_key" {
  type        = string
  sensitive   = true
  description = "Typesense API key for shared instance (applications use collection prefixes for isolation)"
}

variable "typesense_storage_size" {
  type        = string
  default     = "15Gi"
  description = "Persistent volume size for Typesense (increased for shared instance)"
}

# ====================================================================================
# KEYCLOAK CONFIGURATION
# ====================================================================================

variable "keycloak_admin_user" {
  type    = string
  default = "admin"
}

variable "keycloak_admin_password" {
  type      = string
  sensitive = true
}

variable "keycloak_postgres_password" {
  type      = string
  sensitive = true
  default   = "postgres"
}

# ====================================================================================
# GRAFANA CLOUD CONFIGURATION
# ====================================================================================

variable "grafana_cloud_prometheus_url" {
  type        = string
  description = "Grafana Cloud Prometheus remote write URL (e.g., https://prometheus-prod-XX-XX.grafana.net)"
}

variable "grafana_cloud_prometheus_user" {
  type        = string
  description = "Grafana Cloud Prometheus username (Instance ID)"
}

variable "grafana_cloud_api_token" {
  type        = string
  sensitive   = true
  description = "Grafana Cloud API token (used for all services: Prometheus, Loki, Tempo)"
}

variable "grafana_cloud_loki_url" {
  type        = string
  description = "Grafana Cloud Loki URL (e.g., https://logs-prod-XX-XX.grafana.net)"
}

variable "grafana_cloud_loki_user" {
  type        = string
  description = "Grafana Cloud Loki username (Instance ID)"
}

variable "grafana_cloud_tempo_url" {
  type        = string
  description = "Grafana Cloud Tempo OTLP endpoint (e.g., https://tempo-prod-XX-XX.grafana.net:443)"
}

variable "grafana_cloud_tempo_user" {
  type        = string
  description = "Grafana Cloud Tempo username (Instance ID)"
}

# ====================================================================================
# REDIS CONFIGURATION
# ====================================================================================

variable "redis_password" {
  type        = string
  sensitive   = true
  description = "Redis password for shared instance (applications use key prefixes for isolation)"
}

variable "redis_storage_size" {
  type        = string
  default     = "4Gi"
  description = "Persistent volume size for Redis AOF/RDB snapshots"
}

variable "redis_storage_class" {
  type        = string
  default     = "local-path"
  description = "Storage class for Redis persistent volume"
}

variable "redis_insight_enabled" {
  type        = bool
  default     = true
  description = "Enable Redis Insight UI deployment (accessible at redisinsight.<base_domain>)"
}

# ====================================================================================
# OLLAMA LLM SERVICE CONFIGURATION
# ====================================================================================

variable "ollama_enabled" {
  type        = bool
  default     = true
  description = "Enable Ollama LLM service deployment"
}

variable "ollama_helm_chart_version" {
  type        = string
  description = "Ollama Helm chart version"
  default     = "0.30.0"
}

variable "ollama_image_tag" {
  type        = string
  description = "Ollama Docker image tag"
  default     = "0.17.7"
}

variable "ollama_default_model" {
  type        = string
  description = "Default LLM model to download on initialization"
  default     = "qwen2.5:3b"
}

variable "ollama_storage_size" {
  type        = string
  description = "Persistent volume size for model storage"
  default     = "20Gi"
}

variable "ollama_memory_request" {
  type        = string
  description = "Memory request for Ollama pod"
  default     = "2Gi"
}

variable "ollama_memory_limit" {
  type        = string
  description = "Memory limit for Ollama pod"
  default     = "8Gi"
}

variable "ollama_cpu_request" {
  type        = string
  description = "CPU request for Ollama pod"
  default     = "500m"
}

variable "ollama_cpu_limit" {
  type        = string
  description = "CPU limit for Ollama pod"
  default     = "4000m"
}

# ====================================================================================
# HEADLAMP (K8S DASHBOARD) CONFIGURATION
# ====================================================================================

variable "headlamp_enabled" {
  type        = bool
  default     = true
  description = "Enable Headlamp Kubernetes dashboard deployment (accessible at k8s.<base_domain>)"
}

variable "headlamp_helm_chart_version" {
  type        = string
  description = "Headlamp Helm chart version"
  default     = "0.41.0"
}


variable "headlamp_memory_request" {
  type        = string
  description = "Memory request for Headlamp pod"
  default     = "128Mi"
}

variable "headlamp_memory_limit" {
  type        = string
  description = "Memory limit for Headlamp pod"
  default     = "256Mi"
}

variable "headlamp_cpu_request" {
  type        = string
  description = "CPU request for Headlamp pod"
  default     = "100m"
}

variable "headlamp_cpu_limit" {
  type        = string
  description = "CPU limit for Headlamp pod"
  default     = "500m"
}


variable "headlamp_oidc_realm" {
  type        = string
  default     = "master"
  description = "Keycloak realm name for Headlamp OIDC (e.g., master)"
}

variable "headlamp_oidc_client_id" {
  type        = string
  default     = "headlamp"
  description = "Keycloak OIDC client ID for Headlamp"
}

variable "headlamp_oidc_client_secret" {
  type        = string
  sensitive   = true
  description = "Keycloak OIDC client secret for Headlamp (from Keycloak client credentials)"
}

variable "headlamp_oidc_scopes" {
  type        = string
  default     = "profile,email"
  description = "Comma-separated OIDC scopes for Headlamp (openid is always added automatically)"
}

