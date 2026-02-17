# ====================================================================================
# TERRAFORM PROVIDER CONFIGURATION
# ====================================================================================
# Configures required providers and Kubernetes backend for state storage
# ====================================================================================

terraform {
  required_version = ">= 1.5"

  # Store state in Kubernetes secret
  backend "kubernetes" {
    secret_suffix = "infrastructure-helios"
    namespace     = "kube-system"
    config_path   = "~/.kube/config"
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Kubernetes provider configuration using kubeconfig file
provider "kubernetes" {
  config_path = var.kubeconfig_path
}

# Helm provider configuration for chart deployments
provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

