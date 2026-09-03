# Rancher Deployment Guide

**Deploy Rancher to manage your K3s clusters from a single web UI.**

---

## What Rancher Gives You

| Feature | Description |
|---------|-------------|
| Multi-cluster dashboard | Manage Cluster A + B from one UI |
| Fleet GitOps | Deploy apps across clusters |
| RBAC | Users, roles, projects across clusters |
| Monitoring | Built-in Prometheus/Grafana per cluster |
| Explorer | Visual resource browser, YAML editor |
| Apps & Marketplace | One-click install of Helm charts |
| Cluster provisioning | Create/import/manage K3s clusters |

---

## Prerequisites

- Both K3s clusters running and healthy
- SSH access to Cluster A cp01 (`10.21.10.11`)
- Helm installed on the target cluster
- ~500MB additional RAM for Rancher server

## Quick Deploy (Script)

```bash
cd /mnt/AI/dev/k3slab

# Deploy Rancher on Cluster A
./scripts/deploy-rancher.sh -c a

# Check status
./scripts/deploy-rancher.sh -c a --status

# Uninstall
./scripts/deploy-rancher.sh -c a --uninstall
```

## Quick Deploy (OpenTofu)

```hcl
# rancher.tf (in your root module)
module "rancher" {
  source = "./tofu/rancher"

  cluster_ip        = "10.21.10.11"
  rancher_version   = "2.10.3"
  bootstrap_password = "admin123"
  rancher_hostname   = "rancher.cluster-a.lab"
}
```

```bash
tofu apply -auto-approve
```

---

## Manual Deployment (Step by Step)

### Step 1: SSH to Cluster A

```bash
ssh -i /home/ben/.ssh/id_ed25519 debian@10.21.10.11
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

### Step 2: Install Helm

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Step 3: Add Helm Repos

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update
```

### Step 4: Install cert-manager

Rancher requires cert-manager for TLS certificate management.

```bash
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.17.1 \
  --set crds.enabled=true \
  --wait --timeout 5m

# Verify
kubectl -n cert-manager get pods
```

### Step 5: Create Self-Signed Certificate

```bash
cat <<'EOF' | kubectl apply -f -
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
  namespace: cattle-system
spec:
  secretName: tls-rancher-ingress
  dnsNames:
  - rancher.cluster-a.lab
  issuerRef:
    name: self-signed-issuer
    kind: ClusterIssuer
  commonName: rancher.cluster-a.lab
  duration: 8760h
  renewBefore: 720h
EOF
```

### Step 6: Create Namespace

```bash
kubectl create namespace cattle-system
```

### Step 7: Install Rancher

```bash
helm upgrade --install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --version 2.10.3 \
  --set hostname=rancher.cluster-a.lab \
  --set bootstrapPassword=admin123 \
  --set ingress.tls.source=rancher \
  --set replicas=1 \
  --wait --timeout 10m
```

### Step 8: Verify Installation

```bash
kubectl -n cattle-system get pods
kubectl -n cattle-system rollout status deployment/rancher
```

### Step 9: Get Bootstrap Password

```bash
kubectl get secret --namespace cattle-system bootstrap-secret \
  -o go-template='{{.data.bootstrapPassword|base64decode}}{{printf "\n"}}'
```

---

## Accessing Rancher

### Option A: Port-Forward (Easiest)

```bash
# From the control-plane node
kubectl -n cattle-system port-forward svc/rancher 8443:443 &

# From your workstation browser
# https://localhost:8443
```

### Option B: /etc/hosts + Ingress

Add to your workstation `/etc/hosts`:

```
10.21.10.11 rancher.cluster-a.lab
```

Then access: `https://rancher.cluster-a.lab`

### Option C: NodePort

```bash
# Patch Rancher service to NodePort
kubectl -n cattle-system patch svc rancher -p '{"spec":{"type":"NodePort","ports":[{"port":443,"nodePort":30443}]}}'

# Access from any node
# https://10.21.10.11:30443
```

---

## First Login

1. Open the Rancher URL in your browser
2. You'll see a self-signed certificate warning — click "Advanced" → "Proceed"
3. Username: `admin`
4. Password: the bootstrap password (default: `admin123`)
5. Set a new password when prompted
6. Accept the Terms & Conditions

---

## Importing Existing K3s Clusters

Rancher can manage existing clusters by importing them.

### From the Rancher UI

1. Click "Add Cluster" → "Import Existing"
2. Give it a name (e.g., `k3s-cluster-a`)
3. Copy the import command
4. Run it on the target cluster

### Via CLI

On the target cluster (e.g., Cluster B):

```bash
ssh -i /home/ben/.ssh/id_ed25519 debian@10.21.20.11
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Import into Rancher (run on the cluster you want to import)
curl --insecure -sfL https://rancher.cluster-a.lab/v3/import/XXXX_YOUR_TOKEN_XXXX.yaml | kubectl apply -f -
```

To get the import token, run on the Rancher server:

```bash
# Get the import token
kubectl get secret --namespace cattle-system bootstrap-secret -o jsonpath='{.data.token}'
```

### Register Cluster A (Local)

Cluster A is the "local" cluster where Rancher runs. It's automatically registered.

### Register Cluster B

1. In Rancher UI: "Add Cluster" → "Import Existing"
2. Name: `k3s-cluster-b`
3. Run the generated command on Cluster B

---

## Rancher Configuration

### Set Default Admin Password

```bash
# Via API
curl -k -u admin:<old-password> \
  -X PUT \
  -H 'Content-Type: application/json' \
  -d '{"newPassword":"<new-password>"}' \
  https://rancher.cluster-a.lab/v3/users/changepassword
```

### Enable Fleet (GitOps)

Fleet is enabled by default in Rancher 2.10+. To verify:

```bash
kubectl get pods -n cattle-fleet-system
```

### Configure Monitoring

Rancher can deploy monitoring to managed clusters:

1. In Rancher UI → Cluster → Tools → Monitoring
2. Click "Enable"
3. Customize Prometheus/Grafana settings
4. Click "Deploy"

---

## Uninstalling Rancher

```bash
# Uninstall Rancher
helm uninstall rancher -n cattle-system

# Uninstall cert-manager
helm uninstall cert-manager -n cert-manager

# Delete namespaces
kubectl delete namespace cattle-system
kubectl delete namespace cert-manager

# Delete ClusterIssuer
kubectl delete clusterissuer self-signed-issuer
```

---

## Architecture

```
Workstation Browser
        │
        ▼
   Rancher Server (Cluster A)
   ├── cattle-system namespace
   │   ├── rancher (Deployment, 1 replica)
   │   ├── rancher-webhook
   │   ├── fleet-agent
   │   └── cert-manager
   │
   ├── Manages: Cluster A (local)
   └── Manages: Cluster B (imported)
         │
         ├── Cluster B CP nodes
         └── Cluster B Worker nodes
```

## Resource Requirements

| Component | CPU | RAM |
|-----------|----:|----:|
| Rancher server | ~100m | ~400Mi |
| cert-manager | ~50m | ~100Mi |
| Fleet agent | ~30m | ~100Mi |
| **Total** | **~180m** | **~600Mi** |

This adds ~180m CPU and ~600Mi RAM to the host.

## Troubleshooting

### Rancher pods stuck in Pending

```bash
kubectl -n cattle-system get pods
kubectl -n cattle-system describe pod <pod-name>
# Usually: insufficient resources or node not ready
```

### cert-manager not issuing certificates

```bash
kubectl get certificates -A
kubectl describe certificate tls-rancher-ingress -n cattle-system
kubectl get challenges -A
```

### Cannot access Rancher UI

```bash
# Check Rancher pods
kubectl -n cattle-system get pods

# Check ingress
kubectl -n cattle-system get ingress

# Check service
kubectl -n cattle-system get svc rancher

# Test connectivity
curl -k https://rancher.cluster-a.lab
```

### Rancher UI shows "Connecting to cluster..."

This means Rancher can't reach the cluster's Kubernetes API. Verify:

1. The cluster was imported correctly
2. Network connectivity from Rancher pod to cluster API
3. Fleet agent is running on the imported cluster

```bash
# On imported cluster
kubectl -n cattle-fleet-system get pods
kubectl logs -n cattle-fleet-system -l app=fleet-agent
```
