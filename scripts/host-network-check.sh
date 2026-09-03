#!/usr/bin/env bash
# host-network-check.sh — verify the host's physical network is unchanged.
# Usage:
#   host-network-check.sh baseline   # snapshot current state
#   host-network-check.sh compare    # compare live state vs baseline; FAIL on drift
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASELINE_DIR="${REPO_ROOT}/artifacts/host-network-before"

say()  { printf '\e[32m[ok]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[warn]\e[0m %s\n' "$*"; }
fail() { printf '\e[31m[fail]\e[0m %s\n' "$*"; FAILED=1; }
FAILED=0

snapshot() {
  local dir="$1"; shift
  mkdir -p "${dir}"
  ip addr   > "${dir}/ip-addr.txt"
  ip route  > "${dir}/ip-route.txt"
  ip link   > "${dir}/ip-link.txt"
  nmcli device status   > "${dir}/nmcli-devices.txt" 2>&1 || true
  nmcli connection show > "${dir}/nmcli-connections.txt" 2>&1 || true
}

normalize() {
  grep -vE 'virbr[0-9]' \
    | grep -vE '^[0-9]+:\s+(virbr|vnet|vet|cni|flannel|kube|cilium|br-|docker|tap)' \
    | grep -vE '^\s*$' \
    | sed 's/valid_lft.*//; s/link\/ether .*//; s/altname .*//'
}

compare_file() {
  local name="$1" base="$2" live="$3"
  if [[ ! -s "${base}" ]]; then warn "${name}: no baseline"; return; fi
  if diff -u <(normalize <"${base}") <(normalize <"${live}") > /tmp/hnc.diff 2>&1; then
    say "${name}: unchanged"
  else
    if [[ -s /tmp/hnc.diff ]]; then
      fail "${name}: CHANGED"; sed 's/^/    /' /tmp/hnc.diff
    else
      say "${name}: unchanged (after normalization)"
    fi
  fi
}

case "${1:-}" in
  baseline)
    snapshot "${BASELINE_DIR}"
    say "baseline captured to ${BASELINE_DIR}"
    ;;

  compare)
    LIVE="$(mktemp -d)"
    trap 'rm -rf "${LIVE}"' EXIT
    snapshot "${LIVE}"

    echo "== Host network drift check (vs ${BASELINE_DIR}) =="

    compare_file "ip addr"  "${BASELINE_DIR}/ip-addr.txt"  "${LIVE}/ip-addr.txt"
    compare_file "ip link"  "${BASELINE_DIR}/ip-link.txt"  "${LIVE}/ip-link.txt"

    if diff -u "${BASELINE_DIR}/ip-route.txt" "${LIVE}/ip-route.txt" > /tmp/hnc.route.diff; then
      say "routes: unchanged"
    else
      if grep -vE '^\s*(\+.*10\.21\.|@@|---|\+\+\+|diff )' /tmp/hnc.route.diff | grep -qE '^\+'; then
        fail "routes: unexpected change"; sed 's/^/    /' /tmp/hnc.route.diff
      else
        say "routes: only k3s-lab-net additions (expected)"
      fi
    fi

    compare_file "nmcli connections" "${BASELINE_DIR}/nmcli-connections.txt" "${LIVE}/nmcli-connections.txt"

    echo
    if [[ "${FAILED}" -ne 0 ]]; then
      fail "HOST NETWORK DRIFT DETECTED — stop and investigate"
      exit 1
    fi
    say "Host network unchanged — safe to proceed."
    ;;

  *)
    echo "Usage: $0 {baseline|compare}"
    exit 2
    ;;
esac
