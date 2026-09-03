#!/usr/bin/env bash
# preflight.sh — Host discovery + KVM/libvirt verification.
# READ-ONLY. Creates artifacts/host-network-before/ baseline.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASELINE_DIR="${REPO_ROOT}/artifacts/host-network-before"

say()  { printf '\e[32m[ok]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[warn]\e[0m %s\n' "$*"; }
fail() { printf '\e[31m[fail]\e[0m %s\n' "$*"; exit 1; }

echo "== Phase 0: host discovery (read-only) =="

mkdir -p "${BASELINE_DIR}"
{
  echo "# captured $(date -Is)"
  ip addr show enp4s0 2>/dev/null || true
  echo
  ip -4 route show default
  echo
  echo "# all IPv4 addrs"
  ip -4 addr
} > "${BASELINE_DIR}/ip-physical.txt"

ip addr   > "${BASELINE_DIR}/ip-addr.txt"
ip route  > "${BASELINE_DIR}/ip-route.txt"
ip link   > "${BASELINE_DIR}/ip-link.txt"
nmcli device status   > "${BASELINE_DIR}/nmcli-devices.txt" 2>&1 || warn "nmcli unavailable"
nmcli connection show > "${BASELINE_DIR}/nmcli-connections.txt" 2>&1 || true
cat /etc/resolv.conf > "${BASELINE_DIR}/resolv.conf.txt" 2>/dev/null || true
say "baseline saved to ${BASELINE_DIR}"

echo
echo "== Phase 1: KVM + libvirt verification =="

lsmod | grep -q '^kvm_amd\|^kvm_intel' && say "KVM module loaded" \
  || fail "KVM module not loaded"

virsh -c qemu:///system version >/dev/null 2>&1 && say "libvirt reachable (qemu:///system)" \
  || fail "libvirt not reachable (qemu:///system)"

echo
echo "== Existing libvirt resources (do not touch) =="
virsh -c qemu:///system net-list  --all | sed 's/^/  /'
virsh -c qemu:///system pool-list --all | sed 's/^/  /'
virsh -c qemu:///system list --all | sed 's/^/  /'

echo
echo "== Tooling =="
command -v tofu   >/dev/null && say "tofu $(tofu version -json | jq -r .terraform_version)" \
  || fail "OpenTofu not installed"
command -v cloud-localds >/dev/null && say "cloud-localds present" || warn "cloud-localds missing (needed for cloud-init ISOs)"

echo
echo "== CIDR overlap check =="
# K3s lab uses 10.21.0.0/16 — must NOT overlap with existing k8s-lab-net (10.20.0.0/16)
for cidr in 10.21.0.0/16 10.44.0.0/16 10.45.0.0/16; do
  if ip route show | grep -qE "^${cidr%%/*}"; then
    fail "planned CIDR ${cidr} appears in host routing table"
  fi
done
say "planned CIDRs (10.21/16, 10.42/16, 10.43/16) not present on host"

echo
echo "== Host capacity =="
free -h | sed 's/^/  /'
df -h / | sed 's/^/  /'

echo
say "PREFLIGHT PASSED — ready for Phase 2 (k3s-lab-net via tofu)."
