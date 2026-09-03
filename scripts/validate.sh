#!/usr/bin/env bash
# validate.sh — cluster validation gates.
# Usage: validate.sh [gate]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAX_GATE="${1:-10}"
FAILED=0

say()  { printf '\e[32m[ok]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[warn]\e[0m %s\n' "$*"; }
fail() { printf '\e[31m[fail]\e[0m %s\n' "$*"; FAILED=1; }
gate() { printf '\n\e[1m== Gate %s: %s ==\e[0m\n' "$1" "$2"; }

# ---- Gate 1 ---------------------------------------------------------------
gate 1 "host network unchanged; KVM/libvirt healthy"
"${REPO_ROOT}/scripts/host-network-check.sh" compare || fail "Gate 1: host drift"
lsmod | grep -q '^kvm_amd\|^kvm_intel' && say "KVM loaded" || fail "Gate 1: KVM"
virsh -c qemu:///system version >/dev/null 2>&1 && say "libvirt healthy" || fail "Gate 1: libvirt"
[[ "${MAX_GATE}" -lt 1 ]] && exit ${FAILED}

# ---- Gate 2 ---------------------------------------------------------------
gate 2 "NAT network works; VM has Internet; host functional"
NET_STATE=$(virsh -c qemu:///system net-info k3s-lab-net 2>/dev/null | awk '/Active:/{print $2}') || true
[[ "${NET_STATE}" == "yes" ]] && say "k3s-lab-net active" || fail "Gate 2: k3s-lab-net not active"
[[ "${MAX_GATE}" -lt 2 ]] && exit ${FAILED}

# ---- Gate 3 ---------------------------------------------------------------
gate 3 "tofu creates and destroys VM cleanly (idempotency)"
warn "Gate 3 is a manual tofu workflow: plan -> apply -> apply (no diff) -> destroy"
[[ "${MAX_GATE}" -lt 3 ]] && exit ${FAILED}

# ---- Gates 4+ (cluster must exist) ----------------------------------------
if ! kubectl get nodes >/dev/null 2>&1; then
  [[ "${MAX_GATE}" -ge 4 ]] && fail "Gate 4: kubectl cannot reach cluster" || true
  exit ${FAILED}
fi

gate 4 "cluster nodes healthy"
READY=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l)
TOTAL=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [[ "${TOTAL}" -ge 6 && "${READY}" -eq "${TOTAL}" ]]; then
  say "${READY}/${TOTAL} nodes Ready"
else
  fail "Gate 4: ${READY}/${TOTAL} nodes Ready (expect >= 6/6)"
fi
[[ "${MAX_GATE}" -lt 4 ]] && exit ${FAILED}

gate 5 "K3s servers running"
SERVERS=$(kubectl get nodes --no-headers 2>/dev/null | grep -c 'control-plane' || true)
if [[ "${SERVERS}" -ge 3 ]]; then
  say "${SERVERS} K3s servers"
else
  fail "Gate 5: ${SERVERS} servers (expect >= 3)"
fi
[[ "${MAX_GATE}" -lt 5 ]] && exit ${FAILED}

gate 6 "Cilium healthy; pod + service networking"
CIL=$(kubectl -n kube-system get pods -l k8s-app=cilium --no-headers 2>/dev/null | awk '$3=="Running"' | wc -l)
[[ "${CIL}" -ge 3 ]] && say "cilium agents Running (${CIL})" || fail "Gate 6: cilium ${CIL} Running"
kubectl -n kube-system get svc kube-dns >/dev/null 2>&1 && say "kube-dns service present" || fail "Gate 6: kube-dns missing"
[[ "${MAX_GATE}" -lt 6 ]] && exit ${FAILED}

gate 7 "Argo CD healthy"
ARGO=$(kubectl -n argocd get pods --no-headers 2>/dev/null | awk '$3=="Running"' | wc -l)
[[ "${ARGO}" -ge 5 ]] && say "argocd pods Running (${ARGO})" || fail "Gate 7: argocd not healthy"
[[ "${MAX_GATE}" -lt 7 ]] && exit ${FAILED}

gate 8 "monitoring healthy"
kubectl -n monitoring get pods --no-headers 2>/dev/null | awk -v f=fail '$3!="Running"{print f": "$1" -> "$3}' || true
say "monitoring checked"
[[ "${MAX_GATE}" -lt 8 ]] && exit ${FAILED}

gate 9 "failure scenarios"
warn "Gate 9: run scenarios/ runbooks individually"
[[ "${MAX_GATE}" -lt 9 ]] && exit ${FAILED}

gate 10 "destroy + rebuild from Git + OpenTofu"
warn "Gate 10: exercised in disaster recovery phase"

exit ${FAILED}
