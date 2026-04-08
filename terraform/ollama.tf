# ====================================================================================
# OLLAMA LLM SERVICE
# ====================================================================================
# Deploys Ollama for local LLM inference via Helm chart
# Provides AI/ML capabilities for applications in the cluster
# ====================================================================================

# PVC created by Terraform so it exists before Helm schedules the pod.
# Using existingClaim in the Helm values avoids the "spec is immutable"
# error that occurs when upgrading a chart that owns its own PVC.
resource "kubernetes_persistent_volume_claim" "ollama" {
  count = var.ollama_enabled ? 1 : 0

  # local-path uses WaitForFirstConsumer binding — PVC stays Pending until the
  # pod is scheduled. Setting wait_until_bound = false prevents Terraform from
  # blocking here forever.
  wait_until_bound = false

  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "local-path"

    resources {
      requests = {
        storage = var.ollama_storage_size
      }
    }
  }

  # local-path does not support volume expansion — ignore size changes on
  # existing PVCs. Update ollama_storage_size only when creating from scratch.
  lifecycle {
    ignore_changes = [spec[0].resources[0].requests]
  }

  depends_on = [kubernetes_namespace.infra_production]
}

# Create Helm values file for Ollama
resource "local_file" "ollama_values" {
  count    = var.ollama_enabled ? 1 : 0
  filename = "${path.module}/values/ollama-values.yaml"
  content  = <<-EOT
    # Ollama Helm Chart Values
    # Managed by Terraform — chart v1.54.0+

    image:
      repository: ollama/ollama
      tag: ${var.ollama_image_tag}
      pullPolicy: IfNotPresent

    service:
      type: ClusterIP
      port: 11434

    resources:
      requests:
        memory: ${var.ollama_memory_request}
        cpu: ${var.ollama_cpu_request}
      limits:
        memory: ${var.ollama_memory_limit}
        cpu: ${var.ollama_cpu_limit}

    # Persistent storage so models survive pod restarts
    # Uses the existing PVC created by the previous chart version.
    # This avoids the "spec is immutable" error on upgrade.
    persistentVolume:
      enabled: true
      existingClaim: "ollama"

    ollama:
      # Pull models on container startup (persisted, so only downloads once)
      models:
        pull:
    %{ for model in var.ollama_models ~}
          - ${model}
    %{ endfor ~}

    # Environment variables
    extraEnv:
      - name: OLLAMA_HOST
        value: "0.0.0.0:11434"
      - name: OLLAMA_DEBUG
        value: "0"
      - name: GIN_MODE
        value: "release"

    livenessProbe:
      enabled: true
      path: /
      initialDelaySeconds: 60
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 6

    readinessProbe:
      enabled: true
      path: /
      initialDelaySeconds: 30
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 6
  EOT
}

# Deploy Ollama using Helm
resource "helm_release" "ollama_production" {
  count      = var.ollama_enabled ? 1 : 0
  name       = "ollama"
  repository = "https://otwld.github.io/ollama-helm/"
  chart      = "ollama"
  version    = var.ollama_helm_chart_version
  namespace  = kubernetes_namespace.infra_production.metadata[0].name

  cleanup_on_fail = true

  # Force Helm to run upgrade on every apply to detect and fix drift
  # This ensures manually deleted resources get recreated
  force_update = true

  # Wait for deployment to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    local_file.ollama_values[0].content
  ]

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "service.port"
    value = "11434"
  }

  depends_on = [
    local_file.ollama_values,
    kubernetes_namespace.infra_production,
    kubernetes_persistent_volume_claim.ollama,
  ]
}
