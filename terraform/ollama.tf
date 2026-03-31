# ====================================================================================
# OLLAMA LLM SERVICE
# ====================================================================================
# Deploys Ollama for local LLM inference via Helm chart
# Provides AI/ML capabilities for applications in the cluster
# ====================================================================================

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

    # Persistent storage so models survive pod restarts
    persistentVolume:
      enabled: true
      size: ${var.ollama_storage_size}
      storageClass: "local-path"
      accessModes:
        - ReadWriteOnce

    ollama:
      # Pull model on container startup (persisted, so only downloads once)
      models:
        - ${var.ollama_default_model}

    # Override command to filter health-check probe noise from logs.
    # Kubernetes liveness/readiness probes hit GET "/" every few seconds;
    # GIN always logs them. We pipe stderr+stdout through grep to drop those lines.
    command:
      - /bin/sh
      - -c
      - |
        /bin/ollama serve 2>&1 | grep -Ev --line-buffered 'GET[[:space:]]+"/"'

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
      httpGet:
        path: /
        port: 11434
      initialDelaySeconds: 60
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 6

    readinessProbe:
      enabled: true
      httpGet:
        path: /
        port: 11434
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

  # Force recreation if values change significantly
  recreate_pods   = true
  cleanup_on_fail = true
  replace         = true

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
  ]
}
