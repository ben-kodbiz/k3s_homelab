#!/usr/bin/env bash
# delete-vm.sh — Safely destroy a single VM and its volumes.
set -euo pipefail

VM_NAME="$1"
POOL_NAME="${2:-default}"

say()  { printf '\e[32m[ok]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[warn]\e[0m %s\n' "$*"; }

echo "Destroying VM: ${VM_NAME}"

# Stop if running
if virsh -c qemu:///system dominfo "${VM_NAME}" >/dev/null 2>&1; then
  virsh -c qemu:///system destroy "${VM_NAME}" 2>/dev/null || true
fi

# Undefine
virsh -c qemu:///system undefine "${VM_NAME}" --nvram 2>/dev/null || \
  virsh -c qemu:///system undefine "${VM_NAME}" 2>/dev/null || true

# Remove volumes
for vol in "${VM_NAME}-root.qcow2" "${VM_NAME}-seed.iso"; do
  if virsh -c qemu:///system vol-info --pool "${POOL_NAME}" "${vol}" >/dev/null 2>&1; then
    virsh -c qemu:///system vol-delete --pool "${POOL_NAME}" "${vol}" 2>/dev/null || warn "Could not delete vol ${vol}"
  fi
done

say "VM ${VM_NAME} destroyed"
