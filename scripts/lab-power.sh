#!/usr/bin/env bash
# lab-power.sh — stop / start / pause / resume / status the K3s lab VMs.
# Covers ONLY this project's VMs (cp/wk *-cluster-[ab]); never touches
# pre-existing host resources (openstack-lab-01, default net, pools, ...).
#
# Usage:
#   lab-power.sh stop              # graceful shutdown both clusters (workers→CPs)
#   lab-power.sh start             # start all VMs (CPs first), staggered, wait Ready
#   lab-power.sh pause             # virsh managedsave all (RAM to disk, frees RAM+CPU)
#   lab-power.sh resume            # resume from managedsave (same as start)
#   lab-power.sh status            # show VM states + node readiness
#   lab-power.sh stop -c a         # only cluster a (also: -c b)
#   lab-power.sh start -c a,b      # both clusters
#
# Stagger: VMs start ${STAGGER:-15}s apart to avoid cold-boot CPU storms.
# Override: LAB_POWER_STAGGER=30 ./scripts/lab-power.sh start
# Disable:  LAB_POWER_NO_STAGGER=1 ./scripts/lab-power.sh start
set -euo pipefail

PROJ_VM_RE='^(cp|wk)[0-9]+-cluster-[ab]$'
CPS=(cp01 cp02 cp03)
WKS=(wk01 wk02 wk03)
SSH_KEY="/home/ben/.ssh/id_ed25519"
SSH_USER="debian"

# Cluster A: 10.21.10.{11-23}
# Cluster B: 10.21.20.{11-23}
declare -A CLUSTER_IPS=(
  [a]="10.21.10.11"
  [b]="10.21.20.11"
)

say()  { printf '\e[32m[ok]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[warn]\e[0m %s\n' "$*"; }
die()  { printf '\e[31m[fail]\e[0m %s\n' "$*"; exit 1; }

usage() { grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

# ---- arg parsing ------------------------------------------------------------
CMD=""
CLUSTERS=(${LAB_CLUSTERS_DEFAULT:-a b})
while [ $# -gt 0 ]; do
  case "$1" in
    stop|start|pause|resume|status) CMD="$1" ;;
    -c|--clusters) shift; IFS=',' read -ra CLUSTERS <<< "${1:-}" ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
  shift
done
[ -n "${CMD}" ] || usage
[ "${CMD}" = "resume" ] && CMD="start"

vms_for() {
  local c="$1"
  for n in "${CPS[@]}" "${WKS[@]}"; do echo "$n-cluster-$c"; done
}

all_vms() {
  local c
  for c in "${CLUSTERS[@]}"; do vms_for "$c"; done
}

existing_vms() {
  local vm known
  known="$(virsh -c qemu:///system list --all --name 2>/dev/null || true)"
  for vm in $(all_vms); do
    grep -qx "$vm" <<< "$known" && echo "$vm"
  done
}

# ---- commands ---------------------------------------------------------------

cmd_stop() {
  local c n
  local targets=()
  for c in "${CLUSTERS[@]}"; do
    # graceful: workers first, then CPs
    for n in "${WKS[@]}" "${CPS[@]}"; do
      local dom="$n-cluster-$c"
      [ "$(virsh -c qemu:///system domstate "$dom" 2>/dev/null)" = "running" ] && targets+=("$dom") && virsh -c qemu:///system shutdown "$dom" >/dev/null && say "shutdown requested: $dom"
    done
  done
  [ ${#targets[@]} -eq 0 ] && { warn "nothing running to stop"; return 0; }

  say "waiting up to 90s for graceful ACPI shutdown..."
  local waited=0 still=()
  while [ $waited -lt 90 ]; do
    still=()
    for dom in "${targets[@]}"; do
      [ "$(virsh -c qemu:///system domstate "$dom" 2>/dev/null)" != "shut off" ] && still+=("$dom")
    done
    [ ${#still[@]} -eq 0 ] && break
    sleep 10; waited=$((waited+10))
  done
  if [ ${#still[@]} -gt 0 ]; then
    for dom in "${still[@]}"; do
      warn "$dom did not shut down gracefully — destroying (hard off)"
      virsh -c qemu:///system destroy "$dom" >/dev/null 2>&1 || true
    done
  fi
  say "lab stopped ($([ ${#targets[@]} -eq 1 ] && echo 1 VM || echo ${#targets[@]} VMs)). Host RAM/CPU freed."
}

cmd_pause() {
  local dom
  for dom in $(existing_vms); do
    [ "$(virsh -c qemu:///system domstate "$dom" 2>/dev/null)" = "running" ] || continue
    virsh -c qemu:///system managedsave "$dom" >/dev/null && say "saved: $dom"
  done
  say "lab paused (managedsave). RAM freed; resume with: $0 start"
}

STAGGER="${LAB_POWER_STAGGER:-15}"
NO_STAGGER="${LAB_POWER_NO_STAGGER:-}"

cmd_start() {
  local c n dom
  local total=0 started=0
  for c in "${CLUSTERS[@]}"; do
    for n in "${CPS[@]}" "${WKS[@]}"; do
      dom="$n-cluster-$c"
      state="$(virsh -c qemu:///system domstate "$dom" 2>/dev/null || true)"
      { [ "$state" = "shut off" ] || [ "$state" = "pmsuspended" ] || virsh -c qemu:///system dominfo "$dom" 2>/dev/null | grep -q "managed save"; } && total=$((total+1))
    done
  done
  for c in "${CLUSTERS[@]}"; do
    for n in "${CPS[@]}" "${WKS[@]}"; do
      dom="$n-cluster-$c"
      local state
      state="$(virsh -c qemu:///system domstate "$dom" 2>/dev/null || true)"
      if [ "$state" = "shut off" ] || [ "$state" = "pmsuspended" ] || virsh -c qemu:///system dominfo "$dom" 2>/dev/null | grep -q "managed save"; then
        if [ "$started" -gt 0 ] && [ -z "$NO_STAGGER" ]; then
          say "  (waiting ${STAGGER}s — stagger for host heat control; LAB_POWER_NO_STAGGER=1 to disable)"
          sleep "$STAGGER"
        fi
        virsh -c qemu:///system start "$dom" >/dev/null && say "started: $dom" && started=$((started+1))
      elif [ "$state" = "running" ]; then
        warn "$dom already running — skipping"
      fi
    done
  done
  say "VMs starting ($started VMs, staggered ~$((started * STAGGER))s total ramp)"
  wait_ready
}

k3s_ready() {
  local ip="$1" ready total
  ip="${CLUSTER_IPS[$1]:-}"
  [ -z "$ip" ] && { echo "n/a"; return; }
  total=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -i "$SSH_KEY" "$SSH_USER@$ip" \
    "kubectl get nodes --no-headers 2>/dev/null" 2>/dev/null | wc -l)
  ready=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -i "$SSH_KEY" "$SSH_USER@$ip" \
    "kubectl get nodes --no-headers 2>/dev/null" 2>/dev/null | awk '$2=="Ready"' | wc -l)
  echo "${ready}/${total}"
}

wait_ready() {
  local i a b done_a done_b
  say "waiting for nodes to become Ready (up to ~5 min)..."
  for i in $(seq 1 30); do
    a="n/a"; b="n/a"
    [[ " ${CLUSTERS[*]} " == *" a "* ]] && a=$(k3s_ready a)
    [[ " ${CLUSTERS[*]} " == *" b "* ]] && b=$(k3s_ready b)
    printf '\r  t=%3ds  cluster-a: %-5s  cluster-b: %-5s   ' $((i*10)) "$a" "$b"
    done_a=1; done_b=1
    [[ " ${CLUSTERS[*]} " == *" a "* ]] && [ "$a" != "6/6" ] && done_a=0
    [[ " ${CLUSTERS[*]} " == *" b "* ]] && [ "$b" != "6/6" ] && done_b=0
    if [ "$done_a" = 1 ] && [ "$done_b" = 1 ]; then
      echo; say "all selected clusters Ready"; return 0
    fi
    sleep 10
  done
  echo
  warn "not all Ready after 5 min — check: ssh debian@10.21.10.11 'kubectl get nodes'"
  return 1
}

cmd_status() {
  local dom state
  printf '%-22s %-12s\n' "VM" "STATE"
  printf '%-22s %-12s\n' "---" "-----"
  for dom in $(existing_vms | sort); do
    state="$(virsh -c qemu:///system domstate "$dom" 2>/dev/null)"
    printf '%-22s %-12s\n' "$dom" "$state"
  done
  echo ""
  local c ip a b
  for c in "${CLUSTERS[@]}"; do
    ip="${CLUSTER_IPS[$c]:-}"
    [ -z "$ip" ] && continue
    a=$(k3s_ready "$c")
    printf 'cluster-%s (%s) nodes: %s\n' "$c" "$ip" "$a"
  done
  echo ""
  echo "Host:"
  printf '  Load: %s\n' "$(cat /proc/loadavg | awk '{print $1, $2, $3}')"
  printf '  Temp: %s\n' "$(sensors 2>/dev/null | grep 'temp3:' | awk '{print $2}' || echo 'n/a')"
  printf '  RAM:  %s\n' "$(free -h | awk '/Mem:/{print "used:", $3, "/ total:", $2}')"
}

case "${CMD}" in
  stop)   cmd_stop ;;
  start)  cmd_start ;;
  pause)  cmd_pause ;;
  status) cmd_status ;;
  *)      usage ;;
esac
