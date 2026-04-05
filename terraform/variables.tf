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

# ====================================================================================
# CLOUDFLARE CONFIGURATION
# ====================================================================================


variable "cloudflared_enabled" {
  type        = bool
  default     = true
  description = "Deploy cloudflared tunnel daemon (replaces router port forwarding)"
}

variable "cloudflare_tunnel_token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Cloudflare Tunnel token (from Zero Trust dashboard → Networks → Tunnels → Create tunnel → Docker). Embedded tunnel ID + credentials — no cert file needed."
}

variable "cloudflared_image_tag" {
  type        = string
  default     = "2025.4.0"
  description = "cloudflared Docker image tag (pin to a specific release for reproducibility)"
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
  default     = "100Gi"
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
  default     = "30Gi"
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
  default     = "50Gi"
  description = "Persistent volume size for Typesense (increased for shared instance)"
}

# ====================================================================================
# KEYCLOAK CONFIGURATION
# ====================================================================================

variable "keycloak_admin_user" {
  type        = string
  default     = "admin"
  description = "Keycloak admin username"
}

variable "keycloak_admin_password" {
  type        = string
  sensitive   = true
  description = "Keycloak admin password"
}

variable "keycloak_postgres_password" {
  type        = string
  sensitive   = true
  default     = "postgres"
  description = "Password for Keycloak's embedded PostgreSQL database"
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
  default     = "15Gi"
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
  default     = "1.54.0"
}

variable "ollama_image_tag" {
  type        = string
  description = "Ollama Docker image tag"
  default     = "0.19.0"
}

variable "ollama_default_model" {
  type        = string
  description = "Default LLM model to download on initialization"
  default     = "qwen2.5:7b"
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
  default     = "12Gi"
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
  default     = "0.39.0"
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
  default     = "profile email"
  description = "Comma-separated OIDC scopes for Headlamp"
}
