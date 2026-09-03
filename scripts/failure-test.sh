#!/usr/bin/env bash
# failure-test.sh — Run failure/resilience tests on K3s clusters.
# Tests: server node, worker node, pod, deployment, Cilium, DNS, storage.
# Each test verifies recovery, then restores the cluster before the next test.
#
# Usage:
#   failure-test.sh              # Run all tests on cluster A
#   failure-test.sh -c b         # Run on cluster B
#   failure-test.sh --dry-run    # Show what would be tested
set -euo pipefail

SSH_KEY="/home/ben/.ssh/id_ed25519"
SSH_USER="debian"
CLUSTER="a"
DRY_RUN=0
LOG_FILE="/mnt/AI/dev/k3slab/docs/failure-test-results.md"

while [ $# -gt 0 ]; do
  case "$1" in
    -c|--cluster) shift; CLUSTER="${1:-a}" ;;
    --dry-run) DRY_RUN=1 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
  shift
done

declare -A CLUSTER_IPS=([a]="10.21.10.11" [b]="10.21.20.11")
API_IP="${CLUSTER_IPS[$CLUSTER]}"

ssh_k3s() {
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o UserKnownHostsFile=/dev/null \
    -i "$SSH_KEY" "$SSH_USER@$API_IP" "$@"
}

say()  { printf '\e[32m[TEST]\e[0m %s\n' "$*"; }
pass() { printf '\e[32m[PASS]\e[0m %s\n' "$*"; echo "| $1 | PASS |" >> "$LOG_FILE"; }
fail() { printf '\e[31m[FAIL]\e[0m %s\n' "$*"; echo "| $1 | FAIL |" >> "$LOG_FILE"; }
info() { printf '\e[36m[info]\e[0m %s\n' "$*"; }
wait_for_ready() {
  local target="${1:-6}" timeout=120 i=0
  while [ $i -lt $timeout ]; do
    local ready
    ready=$(ssh_k3s "kubectl get nodes --no-headers 2>/dev/null | awk '\$2==\"Ready\"' | wc -l")
    [ "$ready" -ge "$target" ] && return 0
    sleep 5; i=$((i+5))
  done
  return 1
}

# ---- Initialize log ----
cat > "$LOG_FILE" <<EOF
# Failure Test Results — Cluster $CLUSTER

**Date**: $(date -Iseconds)
**API**: $API_IP

| Test | Result |
|------|--------|
EOF

# =====================================================================
# TEST 1: Server Node Failure
# =====================================================================
test_server_node_failure() {
  say "TEST 1: Server Node Failure — stop cp03-cluster-$CLUSTER"
  local server_vm="cp03-cluster-$CLUSTER"

  info "Before: nodes"
  ssh_k3s "kubectl get nodes -o wide"

  info "Stopping $server_vm..."
  virsh -c qemu:///system shutdown "$server_vm" 2>/dev/null || true
  sleep 15
  virsh -c qemu:///system destroy "$server_vm" 2>/dev/null || true

  info "Cluster after server loss:"
  ssh_k3s "kubectl get nodes"
  ssh_k3s "kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null || true"

  local total_pods
  total_pods=$(ssh_k3s "kubectl get pods -A --no-headers 2>/dev/null | grep -c Running || echo 0")
  info "Running pods across cluster: $total_pods"

  info "Restarting $server_vm..."
  virsh -c qemu:///system start "$server_vm" >/dev/null
  sleep 30

  if wait_for_ready 6; then
    pass "Server node failure — cluster recovered with 6/6 nodes"
  else
    fail "Server node failure — not all nodes recovered"
  fi
}

# =====================================================================
# TEST 2: Worker Node Failure
# =====================================================================
test_worker_node_failure() {
  say "TEST 2: Worker Node Failure — stop wk03-cluster-$CLUSTER"
  local worker_vm="wk03-cluster-$CLUSTER"

  info "Before:"
  ssh_k3s "kubectl get nodes"

  info "Stopping $worker_vm..."
  virsh -c qemu:///system shutdown "$worker_vm" 2>/dev/null || true
  sleep 15
  virsh -c qemu:///system destroy "$worker_vm" 2>/dev/null || true

  info "Cluster after worker loss:"
  ssh_k3s "kubectl get nodes"

  local not_ready
  not_ready=$(ssh_k3s "kubectl get nodes --no-headers 2>/dev/null | grep -c NotReady || echo 0")
  local ready
  ready=$(ssh_k3s "kubectl get nodes --no-headers 2>/dev/null | awk '\$2==\"Ready\"' | wc -l")
  info "Ready: $ready, NotReady: $not_ready"

  info "Restarting $worker_vm..."
  virsh -c qemu:///system start "$worker_vm" >/dev/null
  sleep 30

  if wait_for_ready 6; then
    pass "Worker node failure — cluster recovered with 6/6 nodes"
  else
    fail "Worker node failure — not all nodes recovered"
  fi
}

# =====================================================================
# TEST 3: Pod Failure (delete nginx pods)
# =====================================================================
test_pod_failure() {
  say "TEST 3: Pod Failure — delete and verify Recreation"
  ssh_k3s "kubectl delete deployment nginx-test --force --grace-period=0 2>/dev/null || true"
  sleep 2

  info "Deploying 3 nginx-test replicas..."
  ssh_k3s "kubectl create deployment nginx-test --image=nginx:latest --replicas=3 2>/dev/null || true"
  sleep 20

  local before_count
  before_count=$(ssh_k3s "kubectl get pods -l app=nginx-test --no-headers 2>/dev/null | grep -c Running || echo 0")
  info "Pods running before delete: $before_count"

  info "Force-deleting all nginx-test pods..."
  ssh_k3s "kubectl delete pods -l app=nginx-test --force --grace-period=0 2>/dev/null || true"

  info "Waiting 30s for Deployment controller to recreate..."
  sleep 30

  local after_count
  after_count=$(ssh_k3s "kubectl get pods -l app=nginx-test --no-headers 2>/dev/null | grep -c Running || echo 0")
  info "Running pods after recreate: $after_count"

  ssh_k3s "kubectl delete deployment nginx-test --force --grace-period=0 2>/dev/null || true"

  if [ "$after_count" -ge 3 ]; then
    pass "Pod failure — pods recreated ($after_count running)"
  else
    fail "Pod failure — expected 3+ running pods, got $after_count"
  fi
}

# =====================================================================
# TEST 4: Deployment Failure (bad image)
# =====================================================================
test_deployment_failure() {
  say "TEST 4: Deployment Failure — deploy bad image"
  ssh_k3s "kubectl create deployment bad-app --image=nginx:nonexistent-tag-xyz --replicas=2 -n default 2>/dev/null || true"
  sleep 10

  local bad_pods
  bad_pods=$(ssh_k3s "kubectl get pods -l app=bad-app --no-headers 2>/dev/null | grep -c -E 'ErrImagePull|ImagePullBackOff|CrashLoopBackOff' || echo 0")
  info "Bad pods in error state: $bad_pods"

  info "Cleaning up bad deployment..."
  ssh_k3s "kubectl delete deployment bad-app --force --grace-period=0 2>/dev/null || true"
  ssh_k3s "kubectl delete pods -l app=bad-app --force --grace-period=0 2>/dev/null || true"

  if [ "$bad_pods" -ge 1 ]; then
    pass "Deployment failure — bad image detected ($bad_pods pods in error)"
  else
    fail "Deployment failure — error pods not detected"
  fi
}

# =====================================================================
# TEST 5: Cilium Agent Restart
# =====================================================================
test_cilium_failure() {
  say "TEST 5: Cilium Agent Restart"
  ssh_k3s "kubectl -n kube-system get pods -l k8s-app=cilium -o wide"

  info "Deleting all cilium agents..."
  ssh_k3s "kubectl -n kube-system delete pods -l k8s-app=cilium --grace-period=1 2>/dev/null || true"
  sleep 30

  local cilium_ready
  cilium_ready=$(ssh_k3s "kubectl -n kube-system get pods -l k8s-app=cilium --no-headers 2>/dev/null | grep -c Running || echo 0")
  info "Cilium pods running after restart: $cilium_ready"

  local nodes_ready
  nodes_ready=$(ssh_k3s "kubectl get nodes --no-headers 2>/dev/null | awk '\$2==\"Ready\"' | wc -l")
  info "Nodes still Ready: $nodes_ready"

  if [ "$cilium_ready" -ge 6 ] && [ "$nodes_ready" -ge 6 ]; then
    pass "Cilium restart — agents recovered, nodes still Ready"
  else
    fail "Cilium restart — cilium_ready=$cilium_ready, nodes_ready=$nodes_ready"
  fi
}

# =====================================================================
# TEST 6: DNS Failure (delete coredns pods)
# =====================================================================
test_dns_failure() {
  say "TEST 6: DNS Failure — restart CoreDNS"
  ssh_k3s "kubectl -n kube-system get pods -l k8s-app=kube-dns"

  info "Deleting CoreDNS pods..."
  ssh_k3s "kubectl -n kube-system delete pods -l k8s-app=kube-dns --grace-period=1 2>/dev/null || true"
  sleep 15

  local dns_ready
  dns_ready=$(ssh_k3s "kubectl -n kube-system get pods -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c Running || echo 0")
  info "CoreDNS pods running: $dns_ready"

  info "Testing DNS resolution..."
  local dns_works
  dns_works=$(ssh_k3s "kubectl run dns-test --rm -i --restart=Never --image=busybox:1.36 -- nslookup kubernetes.default.svc.cluster.local 2>&1 | grep -c 'Address' || echo 0")

  if [ "$dns_ready" -ge 1 ] && [ "$dns_works" -ge 1 ]; then
    pass "DNS failure — CoreDNS recovered, resolution works"
  else
    fail "DNS failure — dns_ready=$dns_ready, dns_works=$dns_works"
  fi
}

# =====================================================================
# TEST 7: Storage Failure (PVC/Pod behavior)
# =====================================================================
test_storage_failure() {
  say "TEST 7: Storage — PVC and Pod behavior"

  info "Creating PVC and pod..."
  ssh_k3s "kubectl delete pvc test-pvc --force --grace-period=0 2>/dev/null || true"
  ssh_k3s "kubectl delete pod test-pod --force --grace-period=0 2>/dev/null || true"
  sleep 2

  ssh_k3s "cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  resources:
    requests:
      storage: 100Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ['sh', '-c', 'echo data > /mnt/testfile && sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /mnt
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-pvc
YAML"
  sleep 10

  local pod_phase
  pod_phase=$(ssh_k3s "kubectl get pod test-pvc 2>/dev/null || kubectl get pod test-pod -o jsonpath='{.status.phase}' 2>/dev/null || echo Unknown")
  local pvc_status
  pvc_status=$(ssh_k3s "kubectl get pvc test-pvc -o jsonpath='{.status.phase}' 2>/dev/null || echo Unknown")

  info "PVC status: $pvc_status, Pod phase: $pod_phase"

  info "Deleting pod (PVC should persist)..."
  ssh_k3s "kubectl delete pod test-pod --grace-period=5 2>/dev/null || true"
  sleep 5

  local pvc_after
  pvc_after=$(ssh_k3s "kubectl get pvc test-pvc -o jsonpath='{.status.phase}' 2>/dev/null || echo Unknown")
  info "PVC after pod delete: $pvc_after"

  info "Recreating pod with same PVC..."
  ssh_k3s "kubectl run test-pod --restart=Never --image=busybox:1.36 --overrides='{\"spec\":{\"containers\":[{\"name\":\"test-pod\",\"image\":\"busybox:1.36\",\"command\":[\"sh\",\"-c\",\"cat /mnt/testfile 2>/dev/null && sleep 3600\"],\"volumeMounts\":[{\"name\":\"data\",\"mountPath\":\"/mnt\"}]}],\"volumes\":[{\"name\":\"data\",\"persistentVolumeClaim\":{\"claimName\":\"test-pvc\"}}]}}' 2>/dev/null || true"
  sleep 10

  info "Cleaning up..."
  ssh_k3s "kubectl delete pod test-pvc test-pod --force --grace-period=0 2>/dev/null || true"
  ssh_k3s "kubectl delete pvc test-pvc --force --grace-period=0 2>/dev/null || true"

  if [ "$pvc_status" = "Bound" ] && [ "$pvc_after" = "Bound" ]; then
    pass "Storage — PVC bound, survived pod delete/recreate"
  else
    fail "Storage — pvc_status=$pvc_status, pvc_after=$pvc_after"
  fi
}

# =====================================================================
# Run all tests
# =====================================================================
echo ""
echo "============================================"
echo "  FAILURE TESTING — Cluster $CLUSTER"
echo "============================================"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run — would test:"
  echo "  1. Server node failure (cp03-cluster-$CLUSTER)"
  echo "  2. Worker node failure (wk03-cluster-$CLUSTER)"
  echo "  3. Pod failure (delete nginx pods)"
  echo "  4. Deployment failure (bad image)"
  echo "  5. Cilium agent restart"
  echo "  6. DNS failure (CoreDNS restart)"
  echo "  7. Storage (PVC/pod behavior)"
  exit 0
fi

test_server_node_failure
echo ""
test_worker_node_failure
echo ""
test_pod_failure
echo ""
test_deployment_failure
echo ""
test_cilium_failure
echo ""
test_dns_failure
echo ""
test_storage_failure

echo ""
echo "============================================"
echo "  RESULTS"
echo "============================================"
cat "$LOG_FILE"
