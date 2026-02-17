# ============================================================================
# Ollama LLM Service - Helm Chart Deployment
# Provides local LLM inference for services
# ============================================================================

# Create Helm values file for Ollama
resource "local_file" "ollama_values" {
  count    = var.ollama_enabled ? 1 : 0
  filename = "${path.module}/values/ollama-values.yaml"
  content  = <<-EOT
    # Ollama Helm Chart Values
    # Managed by Terraform

    image:
      repository: ollama/ollama
      tag: ${var.ollama_image_tag}
      pullPolicy: IfNotPresent

    service:
      type: ClusterIP
      port: 11434
      targetPort: 11434
      name: ollama-svc

    resources:
      requests:
        memory: ${var.ollama_memory_request}
        cpu: ${var.ollama_cpu_request}
      limits:
        memory: ${var.ollama_memory_limit}
        cpu: ${var.ollama_cpu_limit}

    persistence:
      enabled: true
      size: ${var.ollama_storage_size}
      storageClass: ""  # Use default storage class
      accessMode: ReadWriteOnce

    # Environment variables
    env:
      - name: OLLAMA_HOST
        value: "0.0.0.0:11434"

    # Init container to pull model
    initModels:
      enabled: true
      models:
        - ${var.ollama_default_model}

    livenessProbe:
      enabled: true
      httpGet:
        path: /
        port: 11434
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5

    readinessProbe:
      enabled: true
      httpGet:
        path: /
        port: 11434
      initialDelaySeconds: 10
      periodSeconds: 5
      timeoutSeconds: 3
  EOT
}

# Add Ollama Helm repository
resource "null_resource" "ollama_repo" {
  count = var.ollama_enabled ? 1 : 0

  provisioner "local-exec" {
    command = "helm repo add ollama https://otwld.github.io/ollama-helm/ --force-update && helm repo update"
  }

  triggers = {
    always_run = timestamp()
  }
}

# Deploy Ollama using Helm
resource "helm_release" "ollama_staging" {
  count            = var.ollama_enabled ? 1 : 0
  name             = "ollama"
  repository       = "https://otwld.github.io/ollama-helm/"
  chart            = "ollama"
  version          = var.ollama_helm_chart_version
  namespace        = kubernetes_namespace.apps_staging.metadata[0].name
  
  # Force recreation if values change significantly
  recreate_pods    = true
  cleanup_on_fail  = true
  replace          = false
  
  # Wait for deployment to be ready
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

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
    kubernetes_namespace.apps_staging,
    null_resource.ollama_repo
  ]
}

