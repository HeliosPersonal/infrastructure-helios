#!/bin/bash
# ====================================================================================
# Clean Stuck Namespaces - Remove finalizers from resources blocking deletion
# ====================================================================================
# Run this if namespaces get stuck in Terminating state
# Handles various Kubernetes resources with finalizers
# ====================================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

NAMESPACE="${1:-}"

if [ -z "$NAMESPACE" ]; then
    log_error "Usage: $0 <namespace>"
    log_info "Example: $0 infra-production"
    exit 1
fi

log_info "Cleaning stuck resources in namespace: $NAMESPACE"

# Check if namespace exists and is terminating
STATUS=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

if [ "$STATUS" = "NotFound" ]; then
    log_warn "Namespace $NAMESPACE not found"
    exit 0
fi

if [ "$STATUS" != "Terminating" ]; then
    log_warn "Namespace $NAMESPACE is not in Terminating state (current: $STATUS)"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
        exit 0
    fi
fi

# Try to delete common resources that might have finalizers
log_info "Cleaning up resources with finalizers..."

# Delete any ingresses
kubectl get ingress -n "$NAMESPACE" --no-headers 2>/dev/null | while read -r line; do
    RESOURCE_NAME=$(echo "$line" | awk '{print $1}')
    log_info "Deleting ingress: $RESOURCE_NAME"
    kubectl patch ingress "$RESOURCE_NAME" -n "$NAMESPACE" \
        -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    kubectl delete ingress "$RESOURCE_NAME" -n "$NAMESPACE" \
        --force --grace-period=0 2>/dev/null || true
done

# Delete any PVCs
kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null | while read -r line; do
    RESOURCE_NAME=$(echo "$line" | awk '{print $1}')
    log_info "Deleting PVC: $RESOURCE_NAME"
    kubectl patch pvc "$RESOURCE_NAME" -n "$NAMESPACE" \
        -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    kubectl delete pvc "$RESOURCE_NAME" -n "$NAMESPACE" \
        --force --grace-period=0 2>/dev/null || true
done

# Remove finalizers from namespace itself
log_info "Removing finalizers from namespace..."
kubectl get namespace "$NAMESPACE" -o json | \
    jq '.spec.finalizers = []' | \
    kubectl replace --raw /api/v1/namespaces/"$NAMESPACE"/finalize -f - 2>/dev/null || true

# Wait and check
sleep 3

STATUS=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Deleted")
if [ "$STATUS" = "Deleted" ] || [ -z "$STATUS" ]; then
    log_info "✅ Namespace $NAMESPACE successfully deleted!"
else
    log_warn "⚠️  Namespace still in state: $STATUS"
    log_info "Remaining resources:"
    kubectl api-resources --verbs=list --namespaced -o name | \
        xargs -n 1 kubectl get --show-kind --ignore-not-found -n "$NAMESPACE" 2>/dev/null || true
fi

