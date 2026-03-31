# ====================================================================================
# HEADLAMP - Kubernetes Dashboard
# ====================================================================================
# Provides a web-based UI for monitoring and managing the K8s cluster
# Accessible at k8s.<base_domain>
#
# Login (token):
#   kubectl get secret headlamp-token -n monitoring -o jsonpath='{.data.token}' | base64 -d
#
# Login (OIDC / Keycloak):
#   Prerequisites:
#     - k3s API server must be configured with OIDC flags:
#       Run: scripts/configure-k3s-oidc.sh && sudo systemctl restart k3s
#   Setup:
#     1. Import keycloak-headlamp-realm-import.json via Keycloak Admin →
#        master realm → Realm settings → Action → Partial import
#        (creates the "headlamp" client + "headlamp-admins" group)
#     2. Copy the client secret (Clients → headlamp → Credentials) into the
#        HEADLAMP_OIDC_CLIENT_SECRET GitHub/Infisical secret
#     3. Add users to the "headlamp-admins" group to grant access
# ====================================================================================

# ClusterRole for Headlamp - read-only access to all resources
resource "kubernetes_cluster_role" "headlamp" {
  count = var.headlamp_enabled ? 1 : 0

  metadata {
    name = "headlamp-cluster-reader"
    labels = {
      app = "headlamp"
    }
  }

  rule {
    api_groups = ["", "apps", "batch", "networking.k8s.io", "rbac.authorization.k8s.io", "storage.k8s.io", "policy", "autoscaling"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["pods", "nodes"]
    verbs      = ["get", "list"]
  }
}

# ServiceAccount for Headlamp
resource "kubernetes_service_account" "headlamp" {
  count = var.headlamp_enabled ? 1 : 0

  metadata {
    name      = "headlamp"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "headlamp"
    }
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Bind ClusterRole to Headlamp ServiceAccount
resource "kubernetes_cluster_role_binding" "headlamp" {
  count = var.headlamp_enabled ? 1 : 0

  metadata {
    name = "headlamp-cluster-reader"
    labels = {
      app = "headlamp"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.headlamp[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.headlamp[0].metadata[0].name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
}

# Create a long-lived token for the Headlamp ServiceAccount
resource "kubernetes_secret" "headlamp_token" {
  count = var.headlamp_enabled ? 1 : 0

  metadata {
    name      = "headlamp-token"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.headlamp[0].metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [kubernetes_service_account.headlamp]
}

# ClusterRoleBinding for OIDC users in the headlamp-admins Keycloak group
# Maps the "headlamp-admins" group claim to cluster-admin so OIDC-authenticated
# users can access K8s resources through Headlamp
resource "kubernetes_cluster_role_binding" "headlamp_oidc_admins" {
  count = var.headlamp_enabled ? 1 : 0

  metadata {
    name = "headlamp-oidc-admins"
    labels = {
      app = "headlamp"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "Group"
    name      = "headlamp-admins"
    api_group = "rbac.authorization.k8s.io"
  }
}

# Create Helm values file for Headlamp
resource "local_file" "headlamp_values" {
  count    = var.headlamp_enabled ? 1 : 0
  filename = "${path.module}/values/headlamp-values.yaml"
  content  = <<-EOT
    # Headlamp Helm Chart Values
    # Managed by Terraform

    replicaCount: 1

    service:
      type: ClusterIP
      port: 80

    serviceAccount:
      create: false
      name: ${kubernetes_service_account.headlamp[0].metadata[0].name}

    clusterRoleBinding:
      create: false

    resources:
      requests:
        memory: ${var.headlamp_memory_request}
        cpu: ${var.headlamp_cpu_request}
      limits:
        memory: ${var.headlamp_memory_limit}
        cpu: ${var.headlamp_cpu_limit}
    config:
      oidc:
        secret:
          create: true
          name: headlamp-oidc
        clientID: "${var.headlamp_oidc_client_id}"
        clientSecret: "${var.headlamp_oidc_client_secret}"
        issuerURL: "https://${local.keycloak_host}/realms/${var.headlamp_oidc_realm}"
        scopes: "${var.headlamp_oidc_scopes}"
        callbackURL: "https://${local.headlamp_host}/oidc-callback"
        useAccessToken: true
  EOT
}

# Deploy Headlamp using Helm
resource "helm_release" "headlamp" {
  count      = var.headlamp_enabled ? 1 : 0
  name       = "headlamp"
  repository = "https://kubernetes-sigs.github.io/headlamp/"
  chart      = "headlamp"
  version    = var.headlamp_helm_chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  cleanup_on_fail = true
  replace         = true
  force_update    = true

  wait          = true
  wait_for_jobs = true
  timeout       = 300

  values = [
    local_file.headlamp_values[0].content
  ]
  depends_on = [
    local_file.headlamp_values,
    kubernetes_namespace.monitoring,
    kubernetes_cluster_role_binding.headlamp,
    kubernetes_secret.headlamp_token,
  ]
}

# Cloudflare Origin TLS secret in monitoring namespace
# (TLS secrets must be in the same namespace as the ingress)
resource "kubernetes_secret_v1" "cloudflare_origin_monitoring" {
  count = var.headlamp_enabled ? 1 : 0

  metadata {
    name      = "cloudflare-origin"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  type = "kubernetes.io/tls"

  binary_data = {
    "tls.crt" = filebase64("${path.module}/certs/origin.crt")
    "tls.key" = filebase64("${path.module}/certs/origin.key")
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Ingress for Headlamp - accessible at k8s.<base_domain>
resource "kubernetes_ingress_v1" "headlamp" {
  count = var.headlamp_enabled ? 1 : 0

  metadata {
    name      = "headlamp"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/proxy-body-size"    = "8m"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "3600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "3600"
      "nginx.ingress.kubernetes.io/proxy-buffer-size"  = "32k"
      "nginx.ingress.kubernetes.io/proxy-buffers"      = "4 32k"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      secret_name = kubernetes_secret_v1.cloudflare_origin_monitoring[0].metadata[0].name
      hosts       = [local.headlamp_host]
    }

    rule {
      host = local.headlamp_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "headlamp"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.headlamp, helm_release.ingress_nginx, kubernetes_secret_v1.cloudflare_origin_monitoring]
}
