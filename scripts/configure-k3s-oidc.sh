#!/bin/bash
# ============================================================================
# Configure k3s API server for Keycloak OIDC authentication
# Run this on the k3s server node as root
#
# This enables the K8s API server to validate OIDC tokens from Keycloak,
# which is required for Headlamp OIDC login to work.
#
# After running this script, restart k3s:
#   sudo systemctl restart k3s
# ============================================================================

set -euo pipefail

KEYCLOAK_URL="${1:-https://keycloak.devoverflow.org}"
REALM="${2:-master}"
CLIENT_ID="${3:-headlamp}"

CONFIG_FILE="/etc/rancher/k3s/config.yaml"

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

