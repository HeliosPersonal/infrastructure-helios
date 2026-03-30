#!/bin/bash
# ============================================================================
# Configure k3s API server for Keycloak OIDC authentication
# Run this on the k3s server node as root
#
# ⚠️  IMPORTANT: If Keycloak runs INSIDE the k3s cluster, the API server
# cannot reach the OIDC issuer URL during startup (chicken-and-egg problem).
# In that case you must either:
#   a) Use --oidc-issuer-url pointing to a URL reachable BEFORE the cluster
#      is fully up (e.g., the node's IP + NodePort, or a load balancer), OR
#   b) Skip k3s OIDC config entirely and let Headlamp proxy K8s API calls
#      using its own ServiceAccount token (the default behavior).
#
# k3s config locations:
#   /etc/rancher/k3s/config.yaml  — server config (flags)
#   /etc/rancher/k3s/k3s.yaml     — kubeconfig (NOT what we edit)
#
# After running this script, restart k3s:
#   sudo systemctl restart k3s
# ============================================================================

set -euo pipefail

KEYCLOAK_URL="${1:-https://keycloak.devoverflow.org}"
REALM="${2:-master}"
CLIENT_ID="${3:-headlamp}"

# k3s server config — NOT the kubeconfig (k3s.yaml)
CONFIG_FILE="/etc/rancher/k3s/config.yaml"

echo "⚠️  WARNING: If Keycloak runs INSIDE this k3s cluster, adding OIDC"
echo "   flags will prevent the API server from starting (it can't reach"
echo "   the issuer URL before the cluster is up)."
echo ""
echo "   Only proceed if Keycloak is reachable EXTERNALLY (outside the cluster)."
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Configuring k3s OIDC for:"
echo "  Issuer URL: ${KEYCLOAK_URL}/realms/${REALM}"
echo "  Client ID:  ${CLIENT_ID}"
echo "  Config:     ${CONFIG_FILE}"
echo ""

# Backup existing config
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%s)"
    echo "Backed up existing config"
fi

# Check if kube-apiserver-arg already exists in config
if grep -q "kube-apiserver-arg" "$CONFIG_FILE" 2>/dev/null; then
    echo "WARNING: kube-apiserver-arg already exists in $CONFIG_FILE"
    echo "Please manually add the following args:"
    echo ""
    echo '  - "oidc-issuer-url='"${KEYCLOAK_URL}/realms/${REALM}"'"'
    echo '  - "oidc-client-id='"${CLIENT_ID}"'"'
    echo '  - "oidc-username-claim=email"'
    echo '  - "oidc-groups-claim=groups"'
    exit 1
fi

# Append OIDC config
cat >> "$CONFIG_FILE" << EOF

# OIDC Authentication (Keycloak) - added by configure-k3s-oidc.sh
kube-apiserver-arg:
  - "oidc-issuer-url=${KEYCLOAK_URL}/realms/${REALM}"
  - "oidc-client-id=${CLIENT_ID}"
  - "oidc-username-claim=email"
  - "oidc-groups-claim=groups"
EOF

echo "OIDC configuration added to $CONFIG_FILE"
echo ""
echo "Restart k3s to apply:"
echo "  sudo systemctl restart k3s"
echo ""
echo "To revert if something breaks:"
echo "  sudo cp ${CONFIG_FILE}.bak.* ${CONFIG_FILE}"
echo "  sudo systemctl restart k3s"


