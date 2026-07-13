#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# Harvester environment-specific settings
#
# Edit this section before the first run.
#
# This script deploys Redmine to a Kubernetes cluster running on Harvester.
# It is NOT intended to deploy Redmine directly to the Harvester management
# cluster unless that is explicitly what you intend.
# ==============================================================================

# kubectl context of the target workload cluster.
# Check available names with:
#   kubectl config get-contexts
EXPECTED_CONTEXT="REPLACE_WITH_YOUR_KUBERNETES_CONTEXT"
# EXPECTED_CONTEXT="default"

# StorageClass used for PostgreSQL and Redmine persistent data.
# Typical Harvester/RKE2/K3s environments may use "local-path".
STORAGE_CLASS="local-path"

# IngressClass installed in the workload cluster.
# Examples: traefik, nginx
INGRESS_CLASS="traefik"

# Hostname used to access Redmine.
# The client running the browser must be able to resolve this name.
REDMINE_HOST="redmine.example.local"

# URL scheme. Change to https only when TLS is configured separately.
REDMINE_SCHEME="http"

# Kubernetes wait timeout.
TIMEOUT="600s"

# Persistent volume sizes.
POSTGRES_STORAGE_SIZE="5Gi"
REDMINE_STORAGE_SIZE="5Gi"

# ==============================================================================
# Common application settings
# ==============================================================================

NAMESPACE="redmine-on-kubernetes"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_DIR="${ROOT_DIR}/manifests"
REDMINE_URL="${REDMINE_SCHEME}://${REDMINE_HOST}"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

diagnostics() {
  local exit_code=$?

  if [[ ${exit_code} -ne 0 ]]; then
    printf '\n--- diagnostics ---\n' >&2
    kubectl get nodes -o wide 2>/dev/null || true
    kubectl -n "${NAMESPACE}" get all,pvc,ingress 2>/dev/null || true
    kubectl -n "${NAMESPACE}" get events \
      --sort-by='.lastTimestamp' 2>/dev/null | tail -n 50 || true
    kubectl -n "${NAMESPACE}" logs statefulset/postgres \
      --tail=100 2>/dev/null || true
    kubectl -n "${NAMESPACE}" logs deployment/redmine \
      --tail=100 2>/dev/null || true
  fi

  exit "${exit_code}"
}
trap diagnostics EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 \
    || fail "Required command not found: $1"
}

require_file() {
  [[ -f "$1" ]] || fail "Manifest not found: $1"
}

apply_file() {
  local file="$1"
  log "Applying $(basename "${file}")"
  kubectl apply -f "${file}"
}

wait_for_http() {
  local attempts=60
  local interval=5

  log "Checking Redmine endpoint: ${REDMINE_URL}"

  for ((i = 1; i <= attempts; i++)); do
    if curl \
      --silent \
      --show-error \
      --fail \
      --max-time 5 \
      "${REDMINE_URL}" >/dev/null 2>&1; then
      printf 'Redmine responded successfully.\n'
      return 0
    fi

    printf '  attempt %d/%d: not reachable yet\n' "${i}" "${attempts}"
    sleep "${interval}"
  done

  cat >&2 <<EOF

Redmine Pods and Ingress may be ready, but this machine could not reach:
  ${REDMINE_URL}

Check DNS or /etc/hosts, the Ingress address, firewall rules, and any
Harvester network or load-balancer configuration.
EOF
  return 1
}

# ------------------------------------------------------------------------------
# Preconditions
# ------------------------------------------------------------------------------

require_command kubectl
require_command curl

[[ "${EXPECTED_CONTEXT}" != "REPLACE_WITH_YOUR_KUBERNETES_CONTEXT" ]] \
  || fail "Edit EXPECTED_CONTEXT at the beginning of this script"

required_manifests=(
  "00-namespace.yaml"
  "01-secret.yaml"
  "11-postgres-service.yaml"
  "12-postgres-statefulset.yaml"
  "21-redmine-service.yaml"
  "22-redmine-deployment.yaml"
)

for manifest in "${required_manifests[@]}"; do
  require_file "${MANIFEST_DIR}/${manifest}"
done

current_context="$(kubectl config current-context 2>/dev/null || true)"
[[ -n "${current_context}" ]] \
  || fail "kubectl current-context is not set"

[[ "${current_context}" == "${EXPECTED_CONTEXT}" ]] \
  || fail "Current context is '${current_context}', expected '${EXPECTED_CONTEXT}'"

log "Target configuration"
cat <<EOF
Context:          ${EXPECTED_CONTEXT}
Namespace:        ${NAMESPACE}
StorageClass:     ${STORAGE_CLASS}
IngressClass:     ${INGRESS_CLASS}
Redmine URL:      ${REDMINE_URL}
PostgreSQL PVC:   ${POSTGRES_STORAGE_SIZE}
Redmine PVC:      ${REDMINE_STORAGE_SIZE}
EOF

# ------------------------------------------------------------------------------
# Kubernetes platform checks
# ------------------------------------------------------------------------------

log "Checking Kubernetes API and node readiness"
kubectl cluster-info >/dev/null

kubectl wait \
  --for=condition=Ready \
  node \
  --all \
  --timeout="${TIMEOUT}"

kubectl get storageclass "${STORAGE_CLASS}" >/dev/null \
  || fail "StorageClass '${STORAGE_CLASS}' was not found"

kubectl get ingressclass "${INGRESS_CLASS}" >/dev/null \
  || fail "IngressClass '${INGRESS_CLASS}' was not found"

# ------------------------------------------------------------------------------
# Namespace and database credentials
# ------------------------------------------------------------------------------

apply_file "${MANIFEST_DIR}/00-namespace.yaml"

kubectl wait \
  --for=jsonpath='{.status.phase}'=Active \
  "namespace/${NAMESPACE}" \
  --timeout="${TIMEOUT}"

apply_file "${MANIFEST_DIR}/01-secret.yaml"

# ------------------------------------------------------------------------------
# PostgreSQL
#
# PVC is rendered here instead of applying manifests/10-postgres-pvc.yaml so the
# Harvester-side StorageClass is explicit and visible in this single file.
# ------------------------------------------------------------------------------

log "Creating PostgreSQL storage"

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ${STORAGE_CLASS}
  resources:
    requests:
      storage: ${POSTGRES_STORAGE_SIZE}
EOF

apply_file "${MANIFEST_DIR}/11-postgres-service.yaml"
apply_file "${MANIFEST_DIR}/12-postgres-statefulset.yaml"

log "Waiting for PostgreSQL"
kubectl -n "${NAMESPACE}" rollout status \
  statefulset/postgres \
  --timeout="${TIMEOUT}"

kubectl -n "${NAMESPACE}" wait \
  --for=condition=Ready \
  pod \
  -l app=postgres \
  --timeout="${TIMEOUT}"

kubectl -n "${NAMESPACE}" wait \
  --for=jsonpath='{.status.phase}'=Bound \
  pvc/postgres-data \
  --timeout="${TIMEOUT}"

# ------------------------------------------------------------------------------
# Redmine
# ------------------------------------------------------------------------------

log "Creating Redmine storage"

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redmine-files
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ${STORAGE_CLASS}
  resources:
    requests:
      storage: ${REDMINE_STORAGE_SIZE}
EOF

apply_file "${MANIFEST_DIR}/21-redmine-service.yaml"
apply_file "${MANIFEST_DIR}/22-redmine-deployment.yaml"

log "Waiting for Redmine"
kubectl -n "${NAMESPACE}" rollout status \
  deployment/redmine \
  --timeout="${TIMEOUT}"

kubectl -n "${NAMESPACE}" wait \
  --for=condition=Ready \
  pod \
  -l app=redmine \
  --timeout="${TIMEOUT}"

kubectl -n "${NAMESPACE}" wait \
  --for=jsonpath='{.status.phase}'=Bound \
  pvc/redmine-files \
  --timeout="${TIMEOUT}"

# ------------------------------------------------------------------------------
# Ingress
#
# Ingress is rendered here instead of applying manifests/30-ingress.yaml so the
# class and hostname are explicit Harvester-environment settings.
# ------------------------------------------------------------------------------

log "Creating Ingress"

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: redmine
  namespace: ${NAMESPACE}
spec:
  ingressClassName: ${INGRESS_CLASS}
  rules:
    - host: ${REDMINE_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: redmine
                port:
                  number: 3000
EOF

log "Deployment status"
kubectl -n "${NAMESPACE}" get pod,pvc,service,ingress -o wide

wait_for_http

trap - EXIT

cat <<EOF

==============================================================================
Redmine is ready.

URL:      ${REDMINE_URL}
Username: admin
Password: admin

Kubernetes context: ${EXPECTED_CONTEXT}
StorageClass:       ${STORAGE_CLASS}
IngressClass:       ${INGRESS_CLASS}

The initial admin password must be changed after the first login.
==============================================================================
EOF
