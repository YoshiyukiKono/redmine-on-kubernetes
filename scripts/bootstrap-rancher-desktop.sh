#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="redmine-on-kubernetes"
EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-rancher-desktop}"
TIMEOUT="${TIMEOUT:-300s}"
REDMINE_URL="${REDMINE_URL:-http://redmine.localhost}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_DIR="${ROOT_DIR}/manifests"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

diagnostics() {
  exit_code=$?
  if [[ ${exit_code} -ne 0 ]]; then
    printf '\n--- diagnostics ---\n' >&2
    kubectl get nodes -o wide 2>/dev/null || true
    kubectl -n "${NAMESPACE}" get all,pvc,ingress 2>/dev/null || true
    kubectl -n "${NAMESPACE}" get events \
      --sort-by='.lastTimestamp' 2>/dev/null | tail -n 40 || true
    kubectl -n "${NAMESPACE}" logs statefulset/postgres \
      --tail=100 2>/dev/null || true
    kubectl -n "${NAMESPACE}" logs deployment/redmine \
      --tail=100 2>/dev/null || true
  fi
  exit "${exit_code}"
}
trap diagnostics EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

require_file() {
  [[ -f "$1" ]] || fail "Manifest not found: $1"
}

apply() {
  local file="$1"
  log "Applying $(basename "${file}")"
  kubectl apply -f "${file}"
}

wait_for_http() {
  local url="$1"
  local attempts="${2:-60}"
  local interval="${3:-5}"

  log "Waiting for Redmine HTTP response: ${url}"

  for ((i = 1; i <= attempts; i++)); do
    if curl \
      --silent \
      --show-error \
      --fail \
      --max-time 5 \
      --resolve redmine.localhost:80:127.0.0.1 \
      "${url}" >/dev/null 2>&1; then
      printf 'Redmine responded successfully.\n'
      return 0
    fi

    printf '  attempt %d/%d: not ready yet\n' "${i}" "${attempts}"
    sleep "${interval}"
  done

  fail "Redmine did not respond at ${url}"
}

log "Checking local prerequisites"
require_command kubectl
require_command curl

manifest_files=(
  "00-namespace.yaml"
  "01-secret.yaml"
  "10-postgres-pvc.yaml"
  "11-postgres-service.yaml"
  "12-postgres-statefulset.yaml"
  "20-redmine-pvc.yaml"
  "21-redmine-service.yaml"
  "22-redmine-deployment.yaml"
  "30-ingress.yaml"
)

for manifest in "${manifest_files[@]}"; do
  require_file "${MANIFEST_DIR}/${manifest}"
done

current_context="$(kubectl config current-context 2>/dev/null || true)"
[[ -n "${current_context}" ]] || fail "kubectl current-context is not set"

if [[ "${current_context}" != "${EXPECTED_CONTEXT}" ]]; then
  fail "Current context is '${current_context}', expected '${EXPECTED_CONTEXT}'. Set EXPECTED_CONTEXT explicitly only when intentional."
fi

log "Checking Kubernetes API and node readiness"
kubectl cluster-info >/dev/null
kubectl wait \
  --for=condition=Ready \
  node \
  --all \
  --timeout="${TIMEOUT}"

log "Checking Rancher Desktop platform services"
kubectl get storageclass
kubectl get ingressclass
kubectl get ingressclass traefik >/dev/null \
  || fail "IngressClass 'traefik' was not found"

default_storage_classes="$(
  kubectl get storageclass \
    -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}'
)"
[[ -n "${default_storage_classes}" ]] \
  || fail "No default StorageClass was found"

printf 'Default StorageClass:\n%s\n' "${default_storage_classes}"

apply "${MANIFEST_DIR}/00-namespace.yaml"

log "Waiting for namespace"
kubectl wait \
  --for=jsonpath='{.status.phase}'=Active \
  "namespace/${NAMESPACE}" \
  --timeout="${TIMEOUT}"

apply "${MANIFEST_DIR}/01-secret.yaml"

log "Deploying PostgreSQL"
apply "${MANIFEST_DIR}/10-postgres-pvc.yaml"
apply "${MANIFEST_DIR}/11-postgres-service.yaml"
apply "${MANIFEST_DIR}/12-postgres-statefulset.yaml"

kubectl -n "${NAMESPACE}" rollout status \
  statefulset/postgres \
  --timeout="${TIMEOUT}"

kubectl -n "${NAMESPACE}" wait \
  --for=condition=Ready \
  pod \
  -l app=postgres \
  --timeout="${TIMEOUT}"

log "PostgreSQL is ready"
kubectl -n "${NAMESPACE}" get pod,pvc,service

log "Deploying Redmine"
apply "${MANIFEST_DIR}/20-redmine-pvc.yaml"
apply "${MANIFEST_DIR}/21-redmine-service.yaml"
apply "${MANIFEST_DIR}/22-redmine-deployment.yaml"

kubectl -n "${NAMESPACE}" rollout status \
  deployment/redmine \
  --timeout="${TIMEOUT}"

kubectl -n "${NAMESPACE}" wait \
  --for=condition=Ready \
  pod \
  -l app=redmine \
  --timeout="${TIMEOUT}"

log "Redmine Pod is ready"
kubectl -n "${NAMESPACE}" get pod,pvc,service

log "Creating Ingress"
apply "${MANIFEST_DIR}/30-ingress.yaml"
kubectl -n "${NAMESPACE}" get ingress

wait_for_http "${REDMINE_URL}"

trap - EXIT

cat <<EOF

============================================================
Redmine environment is ready.

URL:      ${REDMINE_URL}
User:     admin
Password: admin

Namespace: ${NAMESPACE}
Context:   ${current_context}
============================================================
EOF
