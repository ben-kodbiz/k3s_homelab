#!/usr/bin/env bash
# destroy.sh — SAFELY destroy ONLY this project's resources.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PROJ_NET="k3s-lab-net"
PROJ_VM_RE='^(cp|wk)[0-9]+-cluster-[ab]$'

say()  { printf '\e[32m[ok]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[warn]\e[0m %s\n' "$*"; }
die()  { printf '\e[31m[fail]\e[0m %s\n' "$*"; exit 1; }

NEVER_TOUCH_NETS="default k8s-lab-net staging0 vagrant-libvirt"
NEVER_TOUCH_POOLS="default Download homelab storage"

show_scope() {
  echo "NEVER destroyed by this script:"
  echo "  networks: ${NEVER_TOUCH_NETS}"
  echo "  pools:    ${NEVER_TOUCH_POOLS}"
}

destroy_env() {
  local envdir="$1"
  [[ -d "${envdir}" ]] || die "environment dir not found: ${envdir}"
  say "tofu destroy for ${envdir} (you must type 'yes')"
  (cd "${envdir}" && tofu destroy)
}

destroy_libvirt_extras() {
  echo
  echo "Project-owned libvirt resources to destroy:"
  virsh -c qemu:///system list --all --name 2>/dev/null | grep -E "${PROJ_VM_RE}" | sed 's/^/  VM: /' || true
  virsh -c qemu:///system net-list --all 2>/dev/null | awk '$1=="k3s-lab-net"{print "  net: k3s-lab-net"}' || true
  echo
  read -r -p "Type 'destroy project resources' to continue: " CONFIRM
  [[ "${CONFIRM}" == "destroy project resources" ]] || die "aborted (no confirmation)"

  for vm in $(virsh -c qemu:///system list --all --name 2>/dev/null | grep -E "${PROJ_VM_RE}" || true); do
    warn "destroying VM ${vm}"
    virsh -c qemu:///system destroy "${vm}" >/dev/null 2>&1 || true
    virsh -c qemu:///system undefine "${vm}" --nvram 2>/dev/null || \
      virsh -c qemu:///system undefine "${vm}" 2>/dev/null || true
  done
  if virsh -c qemu:///system net-info "${PROJ_NET}" >/dev/null 2>&1; then
    virsh -c qemu:///system net-destroy "${PROJ_NET}" >/dev/null 2>&1 || true
    virsh -c qemu:///system net-undefine "${PROJ_NET}" >/dev/null 2>&1 || true
  fi
  say "project libvirt leftovers removed"
}

case "${1:-}" in
  --cluster)
    ENV="${2:-cluster-a}"
    ENVDIR="${REPO_ROOT}/tofu/environments/${ENV}"
    [[ -d "${ENVDIR}" ]] || die "unknown environment '${ENV}'"
    show_scope
    destroy_env "${ENVDIR}"
    ;;

  --all-resources)
    show_scope
    destroy_libvirt_extras
    ;;

  "")
    show_scope
    echo
    read -r -p "Environment to destroy (lab|cluster-a|cluster-b|all): " ENV
    case "${ENV}" in
      lab|cluster-a|cluster-b)
        destroy_env "${REPO_ROOT}/tofu/environments/${ENV}"
        ;;
      all)
        for e in cluster-b cluster-a lab; do
          [[ -d "${REPO_ROOT}/tofu/environments/${e}" ]] && destroy_env "${REPO_ROOT}/tofu/environments/${e}"
        done
        destroy_libvirt_extras
        ;;
      *) die "unknown environment '${ENV}'" ;;
    esac
    ;;

  *) echo "Usage: $0 [--cluster cluster-a] [--all-resources]"; exit 2 ;;
esac

echo
say "destroy complete — run ./scripts/host-network-check.sh compare to verify host unchanged"
