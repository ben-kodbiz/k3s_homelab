#!/usr/bin/env bash
# deploy-rancher.sh — Deploy Rancher management server on a K3s cluster.
# Installs cert-manager, then Rancher, then configures bootstrap password.
#
# Usage:
#   deploy-rancher.sh                    # Deploy on Cluster A
#   deploy-rancher.sh -c b               # Deploy on Cluster B
#   deploy-rancher.sh --uninstall        # Remove Rancher
#   deploy-rancher.sh --status           # Check Rancher status
set -euo pipefail

SSH_KEY="/home/ben/.ssh/id_ed25519"
SSH_USER="debian"
CLUSTER="a"
ACTION="deploy"
RANCHER_VERSION="2.10.3"
CERT_MANAGER_VERSION="v1.17.1"
BOOTSTRAP_PASSWORD="admin123"
RANCHER_NAMESPACE="cattle-system"
RANCHER_HOSTNAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    -c|--cluster) shift; CLUSTER="${1:-a}" ;;
    --uninstall) ACTION="uninstall" ;;
    --status) ACTION="status" ;;
    --password) shift; BOOTSTRAP_PASSWORD="${1:-admin123}" ;;
    --hostname) shift; RANCHER_HOSTNAME="${1:-}" ;;
    -h|--help)
      echo "Usage: $0 [-c a|b] [--uninstall] [--status] [--password <pass>] [--hostname <host>]"
      exit 0 ;;
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

say()  { printf '\e[32m[ok]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[warn]\e[0m %s\n' "$*"; }
die()  { printf '\e[31m[fail]\e[0m %s\n' "$*"; exit 1; }

# =====================================================================
# DEPLOY
# =====================================================================
cmd_deploy() {
  say "Deploying Rancher on Cluster $CLUSTER ($API_IP)"

  # Determine hostname
  if [ -z "$RANCHER_HOSTNAME" ]; then
    RANCHER_HOSTNAME="rancher.cluster-${CLUSTER}.lab"
  fi

  say "Hostname: $RANCHER_HOSTNAME"
  say "Bootstrap password: $BOOTSTRAP_PASSWORD"

  # Step 1: Install Helm (if not present)
  say "Step 1: Ensuring Helm is installed..."
  ssh_k3s '
    if ! command -v helm &>/dev/null; then
      curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    helm version --short
  '

  # Step 2: Add Helm repos
  say "Step 2: Adding Helm repositories..."
  ssh_k3s '
    helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
    helm repo add rancher-latest https://releases.rancher.com/server-charts/latest 2>/dev/null || true
    helm repo update
  '

  # Step 3: Create cattle-system namespace
  say "Step 3: Creating namespace..."
  ssh_k3s "kubectl create namespace $RANCHER_NAMESPACE 2>/dev/null || true"

  # Step 4: Install cert-manager
  say "Step 4: Installing cert-manager $CERT_MANAGER_VERSION..."
  ssh_k3s "
    helm upgrade --install cert-manager jetstack/cert-manager \
      --namespace cert-manager \
      --create-namespace \
      --version $CERT_MANAGER_VERSION \
      --set crds.enabled=true \
      --wait --timeout 5m
  "

  # Wait for cert-manager to be ready
  say "Waiting for cert-manager pods..."
  ssh_k3s "
    kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=120s
    kubectl -n cert-manager rollout status deployment/cert-manager-controller --timeout=120s
  "

  # Step 5: Create self-signed ClusterIssuer
  say "Step 5: Creating self-signed ClusterIssuer..."
  ssh_k3s "cat <<'YAML' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: self-signed-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tls-rancher-ingress
  namespace: $RANCHER_NAMESPACE
spec:
  secretName: tls-rancher-ingress
  dnsNames:
  - $RANCHER_HOSTNAME
  issuerRef:
    name: self-signed-issuer
    kind: ClusterIssuer
  commonName: $RANCHER_HOSTNAME
  duration: 8760h
  renewBefore: 720h
YAML"

  # Step 6: Install Rancher
  say "Step 6: Installing Rancher $RANCHER_VERSION..."
  ssh_k3s "
    helm upgrade --install rancher rancher-latest/rancher \
      --namespace $RANCHER_NAMESPACE \
      --version $RANCHER_VERSION \
      --set hostname=$RANCHER_HOSTNAME \
      --set bootstrapPassword=$BOOTSTRAP_PASSWORD \
      --set ingress.tls.source=rancher \
      --set replicas=1 \
      --wait --timeout 10m
  "

  # Step 7: Wait for Rancher to be ready
  say "Step 7: Waiting for Rancher to become ready..."
  ssh_k3s "
    kubectl -n $RANCHER_NAMESPACE rollout status deployment/rancher --timeout=300s
  "

  # Step 8: Get bootstrap password
  say "Step 8: Getting bootstrap secret..."
  local bootstrap_secret
  bootstrap_secret=$(ssh_k3s "kubectl get secret --namespace $RANCHER_NAMESPACE bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{printf \"\n\"}}' 2>/dev/null || echo '$BOOTSTRAP_PASSWORD'")

  echo ""
  echo "============================================"
  echo "  RANCHER DEPLOYED SUCCESSFULLY"
  echo "============================================"
  echo ""
  echo "Cluster:     $CLUSTER"
  echo "Hostname:    $RANCHER_HOSTNAME"
  echo "API Server:  $API_IP"
  echo ""
  echo "Access URL:  https://$RANCHER_HOSTNAME"
  echo "  (add to /etc/hosts: $API_IP $RANCHER_HOSTNAME)"
  echo ""
  echo "Bootstrap:   $bootstrap_secret"
  echo ""
  echo "Quick access (port-forward):"
  echo "  ssh -i $SSH_KEY $SSH_USER@$API_IP"
  echo "  kubectl -n $RANCHER_NAMESPACE port-forward svc/rancher 8443:443 &"
  echo "  Then open: https://localhost:8443"
  echo ""
  echo "First login:"
  echo "  Username: admin"
  echo "  Password: $bootstrap_secret"
  echo ""
}

# =====================================================================
# STATUS
# =====================================================================
cmd_status() {
  say "Rancher status — Cluster $CLUSTER ($API_IP)"

  echo ""
  echo "--- cert-manager ---"
  ssh_k3s "kubectl -n cert-manager get pods 2>/dev/null || echo 'Not installed'"

  echo ""
  echo "--- Rancher ---"
  ssh_k3s "kubectl -n $RANCHER_NAMESPACE get pods 2>/dev/null || echo 'Not installed'"

  echo ""
  echo "--- Rancher Ingress ---"
  ssh_k3s "kubectl -n $RANCHER_NAMESPACE get ingress 2>/dev/null || echo 'No ingress'"

  echo ""
  echo "--- Rancher Service ---"
  ssh_k3s "kubectl -n $RANCHER_NAMESPACE get svc rancher 2>/dev/null || echo 'No service'"
}

# =====================================================================
# UNINSTALL
# =====================================================================
cmd_uninstall() {
  warn "Uninstalling Rancher from Cluster $CLUSTER..."
  read -p "Are you sure? (yes/no): " confirm
  [ "$confirm" = "yes" ] || { echo "Aborted."; exit 0; }

  ssh_k3s "
    helm uninstall rancher -n $RANCHER_NAMESPACE 2>/dev/null || true
    helm uninstall cert-manager -n cert-manager 2>/dev/null || true
    kubectl delete namespace $RANCHER_NAMESPACE 2>/dev/null || true
    kubectl delete namespace cert-manager 2>/dev/null || true
    kubectl delete clusterissuer self-signed-issuer 2>/dev/null || true
  "
  say "Rancher uninstalled."
}

# =====================================================================
case "$ACTION" in
  deploy)   cmd_deploy ;;
  status)   cmd_status ;;
  uninstall) cmd_uninstall ;;
  *)        die "Unknown action: $ACTION" ;;
esac
