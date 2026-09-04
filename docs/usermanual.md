# K3s Kubernetes Lab — Complete User Manual

**A stage-by-stage guide from zero to expert Kubernetes operations.**

---

# TABLE OF CONTENTS

- [Stage 1: Welcome & Orientation](#stage-1-welcome--orientation)
- [Stage 2: Your First Connection](#stage-2-your-first-connection)
- [Stage 3: Understanding the Architecture](#stage-3-understanding-the-architecture)
- [Stage 4: VM Power Management](#stage-4-vm-power-management)
- [Stage 5: kubectl Mastery](#stage-5-kubectl-mastery)
- [Stage 6: Workloads & Deployments](#stage-6-workloads--deployments)
- [Stage 7: Networking with Cilium](#stage-7-networking-with-cilium)
- [Stage 8: Storage — PVC, PV, and Persistence](#stage-8-storage--pvc-pv-and-persistence)
- [Stage 9: Helm — Package Management](#stage-9-helm--package-management)
- [Stage 10: Argo CD & GitOps](#stage-10-argo-cd--gitops)
- [Stage 11: Monitoring — Prometheus & Grafana](#stage-11-monitoring--prometheus--grafana)
- [Stage 12: High Availability & Failure Testing](#stage-12-high-availability--failure-testing)
- [Stage 13: Daily K8s Engineer Simulation](#stage-13-daily-k8s-engineer-simulation)
- [Stage 14: Expert Scenarios & Advanced Topics](#stage-14-expert-scenarios--advanced-topics)
- [Stage 15: Workstation Tools (k9s, kubectx, kubens)](#stage-15-workstation-tools-k9s-kubectx-kubens)
- [Troubleshooting Guide](#troubleshooting-guide)
- [Reference Appendix](#reference-appendix)

---

# Stage 1: Welcome & Orientation

## What This Lab Is

This lab is a **Kubernetes learning environment** built on K3s — a lightweight, certified Kubernetes distribution. It runs on a single physical host using KVM virtualization, creating 12 virtual machines organized into two independent Kubernetes clusters.

The primary purpose is resource-consumption experimentation: measuring whether K3s consumes fewer CPU/RAM resources than a full Kubernetes installation.

## What You Will Learn

By the time you complete all 14 stages, you will be able to:

- SSH into remote servers and navigate Linux systems
- Manage virtual machines with libvirt/KVM
- Operate Kubernetes clusters with kubectl
- Deploy, scale, and troubleshoot workloads
- Understand CNI networking with Cilium
- Manage persistent storage with PVC/PV
- Use Helm for package management
- Implement GitOps with Argo CD
- Monitor clusters with Prometheus and Grafana
- Test high availability and failure recovery
- Perform daily Kubernetes engineer tasks
- Handle advanced debugging and performance tuning
- Use workstation tools (k9s, kubectx, kubens) for efficient operations

## Prerequisites

- A Linux workstation (or SSH access to one)
- Basic command-line familiarity (cd, ls, ssh, cat)
- A text editor (vim, nano, VS Code)
- Curiosity and patience

## Lab Inventory

| Component | Count | Details |
|-----------|------:|---------|
| Physical Host | 1 | AMD Ryzen 5 5600G, 64GB RAM, 901GB NVMe |
| Virtual Machines | 12 | 6 per cluster (3 control-plane + 3 worker) |
| Kubernetes Clusters | 2 | Cluster A (10.21.10.0/24) + Cluster B (10.21.20.0/24) |
| CNI | — | Cilium v1.17.6 |
| Package Manager | — | Helm v3.21.4 |
| GitOps | — | Argo CD v3.5.2 |
| Monitoring | — | Prometheus + Grafana |
| Storage | — | local-path-provisioner v0.0.31 |

---

# Stage 2: Your First Connection

## 2.1 SSH into the First Server

Open a terminal on your workstation and connect to Cluster A's first control-plane node:

```bash
ssh -i /home/ben/.ssh/id_ed25519 debian@10.21.10.11
```

If prompted about host authenticity, type `yes`. The password for all VMs is set in `terraform.tfvars` (default: see your `vm_password` value).

You should see a Linux shell prompt:

```
debian@cp01:~$
```

## 2.2 Explore the System

Run these commands to understand what you're connected to:

```bash
# What operating system?
cat /etc/os-release

# What kernel?
uname -a

# How much RAM?
free -h

# What's running?
systemctl status k3s
```

## 2.3 Verify Kubernetes

K3s is pre-installed. Check it:

```bash
# Check node status
sudo kubectl get nodes

# Check all system pods
sudo kubectl get pods -A

# Check the cluster info
sudo kubectl cluster-info
```

You should see 6 nodes (3 control-plane + 3 worker), all in `Ready` state.

## 2.4 Understanding the Shell Environment

K3s installs its kubectl configuration at `/etc/rancher/k3s/k3s.yaml`. To use `kubectl` without `sudo`:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

To make this permanent, add to your bashrc:

```bash
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
source ~/.bashrc
```

## 2.5 Practice Exercises

1. SSH into every node in Cluster A (`10.21.10.11` through `10.21.10.23`)
2. Verify each node reports `kubectl get nodes` with 6 entries
3. SSH into Cluster B (`10.21.20.11`) and verify it has its own independent 6-node cluster
4. Check that Cluster A and Cluster B are completely independent (different nodes, different API servers)

---

# Stage 3: Understanding the Architecture

## 3.1 Physical Architecture

```
Physical Host: AMD Ryzen 5 5600G (6 Cores / 12 Threads), 64GB RAM
    │
    ├── KVM/QEMU Hypervisor
    │   ├── Cluster A Network: 10.21.10.0/24 (libvirt bridge virbr4)
    │   │   ├── cp01-cluster-a  (10.21.10.11)  Control Plane + etcd
    │   │   ├── cp02-cluster-a  (10.21.10.12)  Control Plane + etcd
    │   │   ├── cp03-cluster-a  (10.21.10.13)  Control Plane + etcd
    │   │   ├── wk01-cluster-a  (10.21.10.21)  Worker
    │   │   ├── wk02-cluster-a  (10.21.10.22)  Worker
    │   │   └── wk03-cluster-a  (10.21.10.23)  Worker
    │   │
    │   └── Cluster B Network: 10.21.20.0/24 (libvirt bridge virbr4)
    │       ├── cp01-cluster-b  (10.21.20.11)  Control Plane + etcd
    │       ├── cp02-cluster-b  (10.21.20.12)  Control Plane + etcd
    │       ├── cp03-cluster-b  (10.21.20.13)  Control Plane + etcd
    │       ├── wk01-cluster-b  (10.21.20.21)  Worker
    │       ├── wk02-cluster-b  (10.21.20.22)  Worker
    │       └── wk03-cluster-b  (10.21.20.23)  Worker
    │
    └── Host Network: 192.168.0.0/24 (enp4s0) — UNTOUCHABLE
```

## 3.2 What K3s Is

K3s is a lightweight, CNCF-certified Kubernetes distribution. Key differences from "full" Kubernetes:

| Feature | Full Kubernetes | K3s |
|---------|----------------|-----|
| Binary size | ~500MB+ | ~50MB |
| Database | external etcd | embedded SQLite or etcd |
| CNI | plugin-based | pluggable (we use Cilium) |
| Ingress | usually Traefik | disabled in this lab |
| Service LB | MetalLB/loadbalancer | disabled in this lab |
| Storage | complex | local-path-provisioner |
| Install time | 30+ minutes | ~1 minute |

## 3.3 What We Disabled and Why

K3s ships with defaults that conflict with our experiment:

| Component | Default State | Our Config | Why Disabled |
|-----------|--------------|------------|--------------|
| Flannel | Enabled | **Disabled** | Replaced by Cilium CNI |
| Traefik | Enabled | **Disabled** | Not needed; use NodePort for testing |
| ServiceLB | Enabled | **Disabled** | Not needed; use NodePort |
| local-storage | Enabled | **Disabled** | Replaced by local-path-provisioner |

## 3.4 Cluster Topology

Each cluster runs an **HA (High Availability)** configuration with **embedded etcd**:

- **3 Control Plane nodes**: Run the Kubernetes API server, scheduler, controller-manager, and etcd database
- **3 Worker nodes**: Run application workloads (pods)
- **Embedded etcd**: Each control plane stores a copy of the cluster state (no external etcd needed)

The first server (`cp01`) initializes the cluster with `--cluster-init`. The other servers join using `--server` flag and the shared cluster token.

## 3.5 Networking

| Network | CIDR | Purpose |
|---------|------|---------|
| Host LAN | 192.168.0.0/24 | Physical host internet access (DO NOT MODIFY) |
| Cluster A | 10.21.10.0/24 | Cluster A node IPs |
| Cluster B | 10.21.20.0/24 | Cluster B node IPs |
| Pod CIDR | 10.44.0.0/16 | Pod IP addresses (Cilium) |
| Service CIDR | 10.45.0.0/16 | Kubernetes Service VIPs |

## 3.6 Component Resource Overhead

From the baseline measurement:

| Component | CPU | RAM | Pods |
|-----------|----:|----:|-----:|
| Cilium (per node) | ~16m | ~167Mi | 1 |
| CoreDNS | 2m | 17Mi | 1 |
| Metrics Server | 3m | 25Mi | 1 |
| Argo CD | 10m | 222Mi | 7 |
| Prometheus stack | ~50m | ~800Mi | 11 |
| **Platform total** | **~177m** | **~2.2Gi** | **34** |

---

# Stage 4: VM Power Management

## 4.1 The lab-power.sh Script

The lab's power management is handled by `scripts/lab-power.sh`. This script manages all 12 VMs safely, staggering startup to avoid CPU storms.

### Basic Commands

```bash
# Navigate to the lab directory
cd /mnt/AI/dev/k3slab

# Check status of all VMs
./scripts/lab-power.sh status

# Start both clusters (staggered, waits for Ready)
./scripts/lab-power.sh start

# Stop both clusters gracefully
./scripts/lab-power.sh stop

# Start only Cluster A
./scripts/lab-power.sh start -c a

# Start only Cluster B
./scripts/lab-power.sh start -c b

# Start both clusters
./scripts/lab-power.sh start -c a,b

# Pause (save RAM to disk, frees memory)
./scripts/lab-power.sh pause

# Resume from pause
./scripts/lab-power.sh resume
```

## 4.2 What "Stagger" Means

When starting 12 VMs simultaneously, the host CPU becomes overwhelmed (we measured 90°C+ temperatures). The script starts VMs 15 seconds apart by default:

```
t=0s   Starting cp01-cluster-a...
t=15s  Starting cp02-cluster-a...
t=30s  Starting cp03-cluster-a...
t=45s  Starting wk01-cluster-a...
...
t=165s Starting wk03-cluster-b...
```

To override:
```bash
LAB_POWER_STAGGER=30 ./scripts/lab-power.sh start    # 30 seconds apart
LAB_POWER_NO_STAGGER=1 ./scripts/lab-power.sh start   # No stagger (dangerous!)
```

## 4.3 Understanding VM States

| State | Meaning | How to Get There |
|-------|---------|-----------------|
| `running` | VM is on, OS is active | `start` |
| `shut off` | VM is powered down | `stop` or `shutdown` |
| `pmsuspended` | VM RAM saved to disk | `pause` |
| `managed save` | Same as pmsuspended | `pause` |

## 4.4 SSH Directly to a VM

You don't need lab-power.sh to SSH. Direct access:

```bash
# Cluster A nodes
ssh debian@10.21.10.11    # cp01 (control-plane)
ssh debian@10.21.10.12    # cp02 (control-plane)
ssh debian@10.21.10.13    # cp03 (control-plane)
ssh debian@10.21.10.21    # wk01 (worker)
ssh debian@10.21.10.22    # wk02 (worker)
ssh debian@10.21.10.23    # wk03 (worker)

# Cluster B nodes
ssh debian@10.21.20.11    # cp01 (control-plane)
ssh debian@10.21.20.21    # wk01 (worker)
```

Password for all: (set in `terraform.tfvars` as `vm_password`)

## 4.5 Using virsh Directly

For advanced VM management, use `virsh` directly:

```bash
# List all VMs
virsh -c qemu:///system list --all

# Check a specific VM
virsh -c qemu:///system dominfo wk03-cluster-a

# Force stop a VM (immediate, no graceful shutdown)
virsh -c qemu:///system destroy wk03-cluster-a

# Start a VM
virsh -c qemu:///system start wk03-cluster-a

# Graceful shutdown
virsh -c qemu:///system shutdown wk03-cluster-a

# View VM console (Ctrl+] to exit)
virsh -c qemu:///system console wk03-cluster-a
```

## 4.6 Practice Exercises

1. Run `./scripts/lab-power.sh status` and verify all 12 VMs are running
2. SSH into `wk03-cluster-b` and run `hostname` to confirm the VM name
3. Stop Cluster B with `./scripts/lab-power.sh stop -c b`, verify Cluster A is unaffected
4. Restart Cluster B with `./scripts/lab-power.sh start -c b`
5. Use `virsh` to check the CPU allocation of `cp01-cluster-a`

---

# Stage 5: kubectl Mastery

## 5.1 Connecting to the Right Cluster

**CRITICAL**: Cluster A and Cluster B are independent. You must specify which cluster to target.

```bash
# From Cluster A's cp01
ssh debian@10.21.10.11
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# From Cluster B's cp01
ssh debian@10.21.20.11
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

Never mix contexts. Always verify which cluster you're talking to:

```bash
# Current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch context (NOT RECOMMENDED — SSH to the right node instead)
```

## 5.2 Core kubectl Commands

### Nodes

```bash
# List all nodes
kubectl get nodes

# Detailed node info
kubectl get nodes -o wide

# Node labels
kubectl get nodes --show-labels

# Describe a specific node (shows events, conditions, resource usage)
kubectl describe node cp01

# Node resources (requires metrics-server)
kubectl top nodes
```

### Pods

```bash
# List all pods in all namespaces
kubectl get pods -A

# List pods in default namespace
kubectl get pods

# List pods with more detail
kubectl get pods -o wide

# Watch pods in real-time (updates every 2 seconds)
kubectl get pods -A --watch

# Get pod YAML
kubectl get pod <pod-name> -o yaml

# Get pod as JSON
kubectl get pod <pod-name> -o json

# JSONPath query (extract specific field)
kubectl get pod <pod-name> -o jsonpath='{.status.phase}'

# List pods sorted by node
kubectl get pods -A --field-selector spec.nodeName=cp01

# List pods by status
kubectl get pods -A --field-selector=status.phase!=Running
```

### Namespaces

```bash
# List namespaces
kubectl get namespaces

# Create namespace
kubectl create namespace my-app

# Delete namespace (deletes ALL resources in it!)
kubectl delete namespace my-app

# List resources in a namespace
kubectl get all -n kube-system
```

### Services

```bash
# List services
kubectl get svc -A

# Describe a service (shows endpoints, selectors)
kubectl describe svc kubernetes -n default

# Get service endpoints
kubectl get endpoints -A
```

### Deployments

```bash
# List deployments
kubectl get deployments -A

# Scale a deployment
kubectl scale deployment nginx --replicas=5

# Rolling restart
kubectl rollout restart deployment nginx

# Check rollout status
kubectl rollout status deployment nginx

# View rollout history
kubectl rollout history deployment nginx
```

### Logs

```bash
# Logs from a pod
kubectl logs <pod-name>

# Logs from all pods with a label
kubectl logs -l app=nginx --all-containers

# Follow logs (like tail -f)
kubectl logs -f <pod-name>

# Logs from previous container instance (crash debugging)
kubectl logs <pod-name> --previous

# Logs with timestamps
kubectl logs <pod-name> --timestamps

# Limit to last 100 lines
kubectl logs <pod-name> --tail=100
```

### Exec

```bash
# Run command in a pod
kubectl exec <pod-name> -- ls /usr/share/nginx/html

# Interactive shell
kubectl exec -it <pod-name> -- /bin/bash

# Run in specific container (multi-container pods)
kubectl exec -it <pod-name> -c <container-name> -- /bin/bash
```

### Debugging

```bash
# Describe a pod (events, conditions, container state)
kubectl describe pod <pod-name>

# Get pod events
kubectl get events --sort-by='.lastTimestamp'

# Get events for a specific pod
kubectl describe pod <pod-name> | grep -A 10 "Events:"

# Debug a node
kubectl describe node <node-name> | grep -A 20 "Conditions:"

# Check resource usage
kubectl top pods
kubectl top nodes
```

### Delete

```bash
# Delete a pod (Deployment will recreate it)
kubectl delete pod <pod-name>

# Delete pod immediately (no grace period)
kubectl delete pod <pod-name> --grace-period=0 --force

# Delete deployment (removes all pods)
kubectl delete deployment <name>

# Delete by label
kubectl delete pods -l app=nginx
```

## 5.3 Working with YAML

Almost everything in Kubernetes is defined by YAML files. Create one:

```yaml
# my-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-test-pod
  labels:
    app: test
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    ports:
    - containerPort: 80
```

Apply it:

```bash
kubectl apply -f my-pod.yaml

# Verify
kubectl get pod my-test-pod

# Delete using the same file
kubectl delete -f my-pod.yaml
```

## 5.4 Imperative vs Declarative

| Approach | Command | When to Use |
|----------|---------|-------------|
| Imperative | `kubectl create deployment nginx --image=nginx` | Quick testing, one-off tasks |
| Declarative | `kubectl apply -f deployment.yaml` | Production, GitOps, reproducibility |

## 5.5 Practice Exercises

1. SSH into cp01-cluster-a, get nodes list, identify all control-plane nodes
2. Create a namespace called `lab-practice`
3. Deploy an nginx pod in `lab-practice` namespace
4. Exec into the pod and install curl (`apt update && apt install -y curl`)
5. Curl localhost from inside the pod
6. Delete the pod, verify it doesn't come back (because it's a bare Pod, not a Deployment)
7. Deploy nginx as a Deployment with 3 replicas, verify 3 pods appear
8. Scale to 5 replicas, then back to 2
9. View logs from all nginx pods
10. Clean up the `lab-practice` namespace

---

# Stage 6: Workloads & Deployments

## 6.1 Pod vs Deployment

| Resource | Purpose | Self-Healing | Scaling |
|----------|---------|-------------|---------|
| Pod | Smallest deployable unit | No | No |
| Deployment | Manages ReplicaSet of Pods | Yes | Yes |
| ReplicaSet | Ensures N identical pods | Yes | Manual |
| StatefulSet | For stateful apps (databases) | Yes | Ordered |

**Rule**: Never deploy bare Pods in production. Always use Deployments.

## 6.2 Deploying Your First Application

```yaml
# hello-world.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
```

```bash
kubectl apply -f hello-world.yaml
kubectl get pods -l app=hello-world
kubectl get deployment hello-world
```

## 6.3 Exposing with a Service

```yaml
# hello-world-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-world
spec:
  selector:
    app: hello-world
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

```bash
kubectl apply -f hello-world-svc.yaml

# Test from inside the cluster
kubectl run curl-test --rm -i --restart=Never --image=curlimages/curl -- \
  curl http://hello-world.default.svc.cluster.local

# Or use wget from another pod
kubectl exec -it <some-pod> -- wget -qO- http://hello-world
```

## 6.4 Service Types

| Type | Access From | Use Case |
|------|-------------|----------|
| ClusterIP | Inside cluster only | Internal microservices |
| NodePort | Any node IP:port | Development, testing |
| LoadBalancer | External LB IP | Cloud environments |
| ExternalName | DNS CNAME | External service alias |

### NodePort Example

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-world-nodeport
spec:
  selector:
    app: hello-world
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
  type: NodePort
```

Access from your workstation:
```bash
curl http://10.21.10.21:30080   # Any cluster A node
```

## 6.5 Labels and Selectors

Labels are key-value pairs attached to resources. They're how Kubernetes connects things.

```bash
# Show all labels on pods
kubectl get pods --show-labels

# Filter by label
kubectl get pods -l app=nginx

# Multiple labels
kubectl get pods -l app=nginx,version=v2

# Label a node
kubectl label node wk01 disk=ssd

# Select by node label
kubectl get pods --field-selector spec.nodeName=wk01
```

## 6.6 Resource Quotas and Limits

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: lab-quota
  namespace: lab-practice
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "4"
    limits.memory: 4Gi
    pods: "20"
```

```bash
# Check quota usage
kubectl describe resourcequota -n lab-practice
```

## 6.7 Ingress (with NodePort since Traefik is disabled)

Since Traefik is disabled, use NodePort for HTTP routing:

```yaml
# nginx-nodeport.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
  type: NodePort
```

## 6.8 Practice Exercises

1. Deploy a Deployment with 5 nginx replicas
2. Create a ClusterIP service for it
3. Test connectivity from inside the cluster
4. Convert the service to NodePort on port 30080
5. Access it from your workstation using any node IP
6. Scale to 10 replicas, watch pods being created
7. Update the image from nginx:1.27 to nginx:1.28, observe rolling update
8. Roll back the update
9. Add resource requests and limits
10. Delete the deployment and service

---

# Stage 7: Networking with Cilium

## 7.1 What Cilium Is

Cilium is a modern Container Network Interface (CNI) plugin. In this lab, it replaces K3s's default Flannel. Cilium provides:

- **Pod-to-pod networking**: Pods on different nodes can communicate
- **Network policies**: Firewall rules between pods
- **Load balancing**: Built-in service load balancing
- **Observability**: Network visibility via Hubble

## 7.2 Verify Cilium Is Running

```bash
# SSH to any control-plane node
ssh debian@10.21.10.11

# Check Cilium pods
kubectl -n kube-system get pods -l k8s-app=cilium

# Expected output: 6 pods (one per node)
# cilium-xxxxx   1/1   Running   0   10m   cp01
# cilium-yyyyy   1/1   Running   0   10m   cp02
# cilium-zzzzz   1/1   Running   0   10m   cp03
# cilium-aaaaa   1/1   Running   0   10m   wk01
# cilium-bbbbb   1/1   Running   0   10m   wk02
# cilium-ccccc   1/1   Running   0   10m   wk03

# Cilium operator (cluster-wide)
kubectl -n kube-system get pods -l k8s-app=cilium-operator

# Expected: 1 pod

# Cilium config
kubectl -n kube-system get configmap cilium-config -o yaml
```

## 7.3 Pod Networking Fundamentals

Every pod gets its own IP address. Test cross-node communication:

```bash
# Deploy pods on different nodes
kubectl run test-a --image=nginx --overrides='{"spec":{"nodeName":"wk01"}}' 
kubectl run test-b --image=nginx --overrides='{"spec":{"nodeName":"wk02"}}'

# Get their IPs
kubectl get pod test-a -o wide
kubectl get pod test-b -o wide

# From test-a, ping test-b's IP
kubectl exec test-a -- ping -c 3 <test-b-ip>

# From test-a, curl test-b's web server
kubectl exec test-a -- curl -s http://<test-b-ip>

# Clean up
kubectl delete pod test-a test-b
```

## 7.4 DNS Resolution

DNS is handled by CoreDNS (built into K3s):

```bash
# Test DNS from a pod
kubectl run dns-test --rm -i --restart=Never --image=busybox:1.36 -- \
  nslookup kubernetes.default.svc.cluster.local

# Expected output:
# Name:      kubernetes.default.svc.cluster.local
# Address:   10.45.0.1

# Test service DNS
kubectl run dns-test --rm -i --restart=Never --image=busybox:1.36 -- \
  nslookup hello-world.default.svc.cluster.local
```

## 7.5 Network Policies

Cilium supports Kubernetes NetworkPolicy. Create a policy that denies all ingress to a pod:

```yaml
# deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

```bash
kubectl apply -f deny-all.yaml

# Now test — traffic should be blocked
kubectl run test-pod --rm -i --restart=Never --image=curlimages/curl -- \
  curl --connect-timeout 3 http://hello-world

# Clean up
kubectl delete networkpolicy deny-all
```

## 7.6 Cilium Status Commands

```bash
# Overall Cilium health
kubectl -n kube-system exec -it $(kubectl -n kube-system get pods -l k8s-app=cilium -o name | head -1) -- cilium status

# Connectivity test
kubectl -n kube-system exec -it $(kubectl -n kube-system get pods -l k8s-app=cilium -o name | head -1) -- cilium connectivity test

# List all endpoints
kubectl -n kube-system exec -it $(kubectl -n kube-system get pods -l k8s-app=cilium -o name | head -1) -- cilium endpoint list
```

## 7.7 Practice Exercises

1. Verify all 6 Cilium pods are running (one per node)
2. Deploy two nginx pods on different worker nodes
3. Ping between them using their pod IPs
4. Create a ClusterIP service and curl it from another pod
5. Verify DNS resolution for the service
6. Create a NetworkPolicy that blocks ingress to one pod
7. Verify the policy works (curl should fail)
8. Delete the policy and verify connectivity is restored
9. Clean up all test resources

---

# Stage 8: Storage — PVC, PV, and Persistence

## 8.1 Storage Concepts

| Concept | What It Is |
|---------|-----------|
| **PersistentVolume (PV)** | A piece of storage in the cluster |
| **PersistentVolumeClaim (PVC)** | A request for storage by a pod |
| **StorageClass** | Defines how PVs are dynamically provisioned |

In this lab, we use `local-path-provisioner` which creates PVs as directories on the node's filesystem.

## 8.2 Verify Storage Classes

```bash
kubectl get storageclass

# Expected:
# NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
# local-path (default) rancher.io/local-path   Delete          WaitForFirstConsumer
```

## 8.3 Create a PVC and Pod

```yaml
# storage-demo.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 100Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: storage-writer
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ['sh', '-c', 'echo "Hello from PVC" > /mnt/data.txt && sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /mnt
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: demo-pvc
```

```bash
kubectl apply -f storage-demo.yaml

# Check PVC is bound
kubectl get pvc demo-pvc

# Check pod is running
kubectl get pod storage-writer

# Verify data was written
kubectl exec storage-writer -- cat /mnt/data.txt
# Output: Hello from PVC
```

## 8.4 Data Persistence Test

Delete the pod and recreate it — data should survive:

```bash
# Delete the pod
kubectl delete pod storage-writer

# Recreate with same PVC
kubectl apply -f storage-demo.yaml

# Verify data persists
kubectl exec storage-writer -- cat /mnt/data.txt
# Output: Hello from PVC
```

## 8.5 PV Lifecycle

```bash
# List PVs
kubectl get pv

# List PVCs
kubectl get pvc

# Describe PVC (shows which PV it's bound to)
kubectl describe pvc demo-pvc

# Describe PV (shows node, path, reclaim policy)
kubectl describe pv <pv-name>
```

## 8.6 Reclaim Policies

| Policy | Behavior |
|--------|----------|
| **Delete** | PV is deleted when PVC is deleted (default for local-path) |
| **Retain** | PV is kept after PVC deletion (manual cleanup) |

## 8.7 Multi-Access Storage

For pods that need to read/write the same volume simultaneously, use `ReadWriteMany` (requires NFS or similar — not available with local-path):

```yaml
# This won't work with local-path (only ReadWriteOnce)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-pvc
spec:
  accessModes:
  - ReadWriteOnce  # Only one node can mount at a time
  storageClassName: local-path
  resources:
    requests:
      storage: 500Mi
```

## 8.8 Cleanup

```bash
kubectl delete -f storage-demo.yaml
kubectl delete pvc demo-pvc
```

## 8.9 Practice Exercises

1. Create a PVC named `test-storage` with 200Mi
2. Create a pod that writes the current date to `/mnt/timestamp.txt`
3. Verify the data was written
4. Delete the pod
5. Create a new pod with the same PVC
6. Verify the timestamp file still exists
7. Create a second PVC and pod on a different node
8. Verify both PVCs are bound to different PVs
9. Describe the PVs and note their node affinity
10. Clean up all storage resources

---

# Stage 9: Helm — Package Management

## 9.1 What Helm Is

Helm is the package manager for Kubernetes. Think of it as `apt` or `npm` for K8s. A "chart" is a package of YAML templates.

```bash
# Verify Helm is installed
helm version

# List configured repositories
helm repo list

# List installed charts
helm list -A
```

## 9.2 Helm Repositories

```bash
# Add common repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

## 9.3 Searching Charts

```bash
# Search for nginx charts
helm search repo nginx

# Search for monitoring charts
helm search repo prometheus

# Show chart details
helm show chart bitnami/nginx
helm show values bitnami/nginx
```

## 9.4 Installing a Chart

```bash
# Install nginx
helm install my-nginx bitnami/nginx -n default

# Check what was installed
kubectl get pods -l app.kubernetes.io/name=nginx
kubectl get svc -l app.kubernetes.io/name=nginx

# Check Helm release
helm list -n default
```

## 9.5 Customizing Values

```bash
# Show default values
helm show values bitnami/nginx > /tmp/nginx-values.yaml

# Edit values
# In nginx-values.yaml, change:
#   replicaCount: 2
#   service:
#     type: NodePort
#     nodePort: 30080

# Install with custom values
helm install my-nginx bitnami/nginx -n default \
  --set replicaCount=2 \
  --set service.type=NodePort \
  --set service.nodePort=30080

# Or from a file
helm install my-nginx bitnami/nginx -n default -f /tmp/nginx-values.yaml
```

## 9.6 Upgrading and Rolling Back

```bash
# Upgrade to new values
helm upgrade my-nginx bitnami/nginx -n default --set replicaCount=5

# Check history
helm history my-nginx -n default

# Rollback to previous version
helm rollback my-nginx 1 -n default
```

## 9.7 Uninstalling

```bash
helm uninstall my-nginx -n default

# Verify cleanup
kubectl get pods -l app.kubernetes.io/name=nginx
```

## 9.8 Helm in This Lab

Charts currently installed:

```bash
helm list -A

# Expected:
# NAME           NAMESPACE    REVISION  STATUS    CHART
# cilium         kube-system  1         deployed  cilium-1.17.6
# argocd         argocd       1         deployed  argo-cd-3.5.2
# kube-prom-stack monitoring  1         deployed  kube-prometheus-stack-1.0.0
```

## 9.9 Practice Exercises

1. Search for Redis charts
2. Install a Redis chart with 1 replica
3. Verify the pod is running
4. Upgrade to 3 replicas
5. Check the Helm release history
6. Roll back to 1 replica
7. Uninstall Redis
8. Install a PostgreSQL chart with custom values (password, database name)
9. Verify you can connect to PostgreSQL from another pod
10. Clean up

---

# Stage 10: Argo CD & GitOps

## 10.1 What GitOps Is

GitOps is a deployment paradigm where:

1. You store desired state in a Git repository
2. A controller (Argo CD) watches the repo
3. When Git changes, Argo CD automatically syncs the cluster

```
Developer → git push → Git Repo → Argo CD → kubectl apply → Cluster
```

## 10.2 Access Argo CD

Argo CD is installed on both clusters. Port-forward to access the web UI:

```bash
# On Cluster A
ssh debian@10.21.10.11
kubectl -n argocd port-forward svc/argocd-server 8080:443 &

# Access from your workstation browser:
# https://10.21.10.11:8080
# Username: admin
# Password: (see terraform.tfvars — not committed to git)
```

For Cluster B:
```
# URL: https://10.21.20.11:8080
# Username: admin
# Password: (see terraform.tfvars — not committed to git)
```

## 10.3 Argo CD CLI

```bash
# Install argocd CLI (on your workstation or any node)
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login
argocd login 10.21.10.11:8080 --username admin --password <ARGOCD_PASSWORD> --insecure

# List applications
argocd app list

# Get app details
argocd app get nginx
```

## 10.4 GitOps Structure in This Lab

The GitOps manifests live in `/mnt/AI/dev/k3slab/gitops/`:

```
gitops/
├── cluster-a/
│   └── apps.yaml          # ApplicationSet for Cluster A
├── cluster-b/
│   └── apps.yaml          # ApplicationSet for Cluster B
└── apps/
    ├── nginx/
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   └── kustomization.yaml
    └── httpbin/
        ├── deployment.yaml
        ├── service.yaml
        └── kustomization.yaml
```

## 10.5 Sync Workflow

1. Edit a YAML file in the `gitops/apps/` directory
2. Commit and push to Git
3. Argo CD detects the change within 3 minutes (or click "Refresh")
4. Argo CD applies the changes to the cluster
5. Verify: `kubectl get pods`

## 10.6 Manual Sync via CLI

```bash
# Force sync an application
argocd app sync nginx

# Check sync status
argocd app get nginx

# View diffs before syncing
argocd app diff nginx
```

## 10.7 Practice Exercises

1. Access Argo CD web UI via port-forward
2. List all applications
3. Check the sync status of nginx and httpbin
4. Edit the nginx deployment YAML to change replica count
5. Push the change to Git (or use Argo CD CLI to sync)
6. Verify the change is applied to the cluster
7. Intentionally break the YAML (invalid syntax), push, observe Argo CD reporting "Unknown"
8. Fix the YAML, push, verify recovery
9. Explore Argo CD's rollback feature
10. Clean up any test applications

---

# Stage 11: Monitoring — Prometheus & Grafana

## 11.1 What's Installed

The `kube-prometheus-stack` Helm chart provides:

- **Prometheus**: Time-series metrics database
- **Grafana**: Visualization dashboards
- **Alertmanager**: Alert routing (not configured in this lab)
- **node-exporter**: Host-level metrics

## 11.2 Accessing Grafana

```bash
# Port-forward Grafana
ssh debian@10.21.10.11
kubectl -n monitoring port-forward svc/grafana 3000:80 &

# Access from workstation browser:
# http://10.21.10.11:3000
# Username: admin
# Password: (set in terraform.tfvars as vm_password)
```

## 11.3 Accessing Prometheus

```bash
# Port-forward Prometheus
ssh debian@10.21.10.11
kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 &

# Access:
# http://10.21.10.11:9090
```

## 11.4 Key Grafana Dashboards

Pre-built dashboards:

| Dashboard | What It Shows |
|-----------|--------------|
| Kubernetes Cluster Overview | Nodes, pods, resource usage |
| Node Exporter Full | CPU, RAM, disk, network per node |
| K3s | K3s-specific metrics |

Navigate: Dashboards → Browse → Search for "Kubernetes"

## 11.5 Useful Prometheus Queries

Open Prometheus web UI (http://10.21.10.11:9090) and try these in the "Graph" tab:

```promql
# CPU usage per node (percentage)
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage per node (percentage)
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Pod CPU usage
sum(rate(container_cpu_usage_seconds_total{namespace="default"}[5m])) by (pod)

# Pod memory usage
sum(container_memory_working_set_bytes{namespace="default"}) by (pod)

# Pod count per node
count by(node) (kube_pod_info)

# Disk usage
node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100
```

## 11.6 Setting Up Port-Forwards Persistently

Port-forwards die when you disconnect SSH. Use systemd user services:

```bash
# On the control-plane node
mkdir -p ~/.config/systemd/user/

cat > ~/.config/systemd/user/grafana-forward.service << 'EOF'
[Unit]
Description=Grafana port-forward
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/kubectl -n monitoring port-forward svc/grafana 3000:80
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable grafana-forward
systemctl --user start grafana-forward

# Check status
systemctl --user status grafana-forward
```

## 11.7 Resource Monitoring Commands

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage (all namespaces)
kubectl top pods -A

# Pod resource usage (sorted by CPU)
kubectl top pods -A --sort-by=cpu

# Pod resource usage (sorted by memory)
kubectl top pods -A --sort-by=memory
```

## 11.8 Practice Exercises

1. Access Grafana via port-forward
2. Find the Kubernetes Cluster Overview dashboard
3. Identify which node uses the most CPU
4. Identify which pod uses the most memory
5. Access Prometheus and run the CPU usage query
6. Run the memory usage query
7. Create a Grafana alert for high CPU (>80%)
8. Use `kubectl top nodes` and `kubectl top pods` to compare with Grafana data
9. Check disk usage on each node
10. Document the resource consumption of each platform component

---

# Stage 12: High Availability & Failure Testing

## 12.1 What HA Means

High Availability means the cluster survives failures:

- **Control Plane HA**: If one control-plane node dies, the API server and etcd still work (quorum = 2 of 3)
- **Worker HA**: If one worker dies, pods on it are rescheduled to other workers
- **Self-Healing**: Deployments automatically replace failed pods

## 12.2 Run Automated Failure Tests

The lab includes a comprehensive failure testing script:

```bash
cd /mnt/AI/dev/k3slab

# Dry run — see what would be tested
./scripts/failure-test.sh --dry-run

# Run all tests on Cluster A
./scripts/failure-test.sh -c a

# Run all tests on Cluster B
./scripts/failure-test.sh -c b
```

### What the Tests Cover

| Test | What Happens | What to Watch |
|------|-------------|---------------|
| Server node failure | cp03 is destroyed | Cluster continues operating with 2 CPs |
| Worker node failure | wk03 is destroyed | Pods rescheduled to other workers |
| Pod failure | All nginx pods deleted | Deployment recreates them automatically |
| Deployment failure | Bad image deployed | Pods show ErrImagePull, cluster stays healthy |
| Cilium restart | All Cilium pods deleted | Network recovers, nodes stay Ready |
| DNS failure | CoreDNS pod deleted | DNS resolution continues after restart |
| Storage | PVC survives pod delete | Data persists across pod restarts |

## 12.3 Manual Failure Testing

### Test: Kill a Control Plane Node

```bash
# From your workstation
virsh -c qemu:///system destroy cp03-cluster-a

# Verify cluster still works (SSH to cp01-cluster-a)
ssh debian@10.21.10.11 'kubectl get nodes'
# Should show cp03 as NotReady, others still Ready

# API server still responds
ssh debian@10.21.10.11 'kubectl get pods -A'

# Bring it back
virsh -c qemu:///system start cp03-cluster-a

# Wait 30s, verify recovery
ssh debian@10.21.10.11 'kubectl get nodes'
```

### Test: Kill a Worker Node

```bash
virsh -c qemu:///system destroy wk03-cluster-a

# Check that pods are rescheduled
ssh debian@10.21.10.11 'kubectl get pods -A -o wide | grep wk03'
# wk03 pods should be gone or in Terminating state

# Other workers should have new pods
ssh debian@10.21.10.11 'kubectl get pods -A -o wide | grep wk01'

# Bring it back
virsh -c qemu:///system start wk03-cluster-a
```

### Test: Pod Self-Healing

```bash
# Deploy 3 nginx pods
ssh debian@10.21.10.11
kubectl create deployment test-heal --image=nginx:1.27 --replicas=3

# Kill a pod
kubectl delete pod <pod-name>

# Watch it come back
kubectl get pods -l app=test-heal --watch

# Clean up
kubectl delete deployment test-heal
```

### Test: Rolling Update

```bash
# Start with nginx 1.27
kubectl create deployment rolling-test --image=nginx:1.27 --replicas=5

# Update to nginx 1.28
kubectl set image deployment rolling-test nginx=nginx:1.28

# Watch the rolling update
kubectl rollout status deployment rolling-test

# If something goes wrong, rollback
kubectl rollout undo deployment rolling-test

# Clean up
kubectl delete deployment rolling-test
```

## 12.4 Understanding Quorum

With 3 etcd nodes, the cluster tolerates **1 node failure**:

| Nodes Alive | Quorum | Cluster Status |
|-------------|--------|----------------|
| 3/3 | Yes (3) | Healthy |
| 2/3 | Yes (2) | Healthy (degraded) |
| 1/3 | No (1) | **DOWN** |

This is why we use 3 control-plane nodes — it provides fault tolerance while maintaining quorum.

## 12.5 Practice Exercises

1. Run `./scripts/failure-test.sh -c a` and verify all 7 tests pass
2. Manually destroy `wk01-cluster-b` and verify pods reschedule
3. Bring `wk01-cluster-b` back and verify it rejoins
4. Deploy a Deployment, scale to 5, kill 2 pods simultaneously, verify recovery
5. Create a NodePort service, access it during a rolling update
6. Kill a control-plane node, verify API server still works from surviving nodes
7. Restore the killed node and verify full recovery

---

# Stage 13: Daily K8s Engineer Simulation

This stage simulates real-world tasks a Kubernetes engineer handles daily. Complete each scenario in order.

## 13.1 Scenario: New Application Deployment

**Request**: "Deploy a new web application called `webapp` with 3 replicas, internal access only, on Cluster A."

```bash
ssh debian@10.21.10.11
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Create namespace
kubectl create namespace webapp

# Create deployment
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:1.27
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
EOF

# Create service
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: webapp
  namespace: webapp
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Verify
kubectl -n webapp get pods
kubectl -n webapp get svc
```

## 13.2 Scenario: Debug a Failing Pod

**Request**: "A pod is stuck in CrashLoopBackOff. Find it and fix it."

```bash
# Find failing pods
kubectl get pods -A | grep -v Running | grep -v Completed

# Or more precisely:
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# Check events for a specific failing pod
kubectl describe pod <pod-name>

# Check logs (including previous crashed instance)
kubectl logs <pod-name> --previous

# Common fixes:
# 1. Image not found → fix image name
# 2. Config error → fix ConfigMap/Secret
# 3. Crash loop → check app logs for error
# 4. Missing dependency → check service/endpoint
```

## 13.3 Scenario: Scale Application for Traffic Spike

**Request**: "We expect 10x traffic tomorrow. Scale the webapp to 15 replicas."

```bash
kubectl -n webapp scale deployment webapp --replicas=15

# Verify all pods are scheduled
kubectl -n webapp get pods -o wide

# Check if any pods are Pending (insufficient resources)
kubectl -n webapp get pods --field-selector=status.phase=Pending

# Monitor resource usage
kubectl top pods -n webapp

# After the spike, scale back down
kubectl -n webapp scale deployment webapp --replicas=3
```

## 13.4 Scenario: Rolling Update with Zero Downtime

**Request**: "Update webapp from nginx:1.27 to nginx:1.28 without downtime."

```bash
# Check current state
kubectl -n webapp get deployment webapp -o jsonpath='{.spec.template.spec.containers[0].image}'

# Update the image
kubectl -n webapp set image deployment/webapp nginx=nginx:1.28

# Watch the rollout
kubectl -n webapp rollout status deployment/webapp

# If problems occur, rollback instantly
kubectl -n webapp rollout undo deployment/webapp

# Check rollout history
kubectl -n webapp rollout history deployment/webapp
```

## 13.5 Scenario: Storage provisioning

**Request**: "The webapp needs persistent storage for user uploads."

```bash
# Create PVC
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: webapp-uploads
  namespace: webapp
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
EOF

# Patch deployment to mount the volume
kubectl -n webapp patch deployment webapp --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/volumes", "value": [{"name": "uploads", "persistentVolumeClaim": {"claimName": "webapp-uploads"}}]},
  {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts", "value": [{"name": "uploads", "mountPath": "/usr/share/nginx/html/uploads"}]}
]'

# Verify PVC is bound
kubectl -n webapp get pvc

# Write test data
kubectl -n webapp exec $(kubectl -n webapp get pods -l app=webapp -o name | head -1) -- \
  echo "test upload" > /usr/share/nginx/html/uploads/test.txt
```

## 13.6 Scenario: Resource Quota Enforcement

**Request**: "The webapp namespace is consuming too many resources. Set limits."

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: webapp-quota
  namespace: webapp
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
    pods: "10"
EOF

# Check quota usage
kubectl -n webapp describe resourcequota webapp-quota

# Try to scale beyond quota (should fail)
kubectl -n webapp scale deployment webapp --replicas=100
# Error: exceeds quota
```

## 13.7 Scenario: Cluster Upgrade Planning

**Request**: "Plan a K3s upgrade from v1.31.4 to the next patch version."

```bash
# Current version
ssh debian@10.21.10.11 'k3s --version'
# k3s version v1.31.4+k3s1

# Check available versions
curl -sL https://update.k3s.io/v1-k3s/channels.json | jq '.[] | select(.channel=="stable")'

# Upgrade procedure (one node at a time):
# 1. Drain the node
kubectl drain wk03 --ignore-daemonsets --delete-emptydir-data

# 2. SSH to the node and upgrade
ssh debian@10.21.10.23
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.31.5+k3s1" sh -s - agent

# 3. Uncordon the node
kubectl uncordon wk03

# 4. Repeat for each node
```

## 13.8 Scenario: Log Aggregation

**Request**: "Find all error logs across the cluster in the last hour."

```bash
# Recent events
kubectl get events --sort-by='.lastTimestamp' -A | grep -i "error\|warn\|fail"

# Logs from specific namespace
kubectl logs -l app=webapp -n webapp --all-containers --since=1h | grep -i error

# Logs from kube-system (system components)
kubectl logs -n kube-system -l k8s-app=cilium --since=1h | grep -i error

# Count error occurrences
kubectl logs -A --all-containers --since=1h 2>/dev/null | grep -ci "error"
```

## 13.9 Scenario: Network Troubleshooting

**Request**: "A pod can't reach another pod. Diagnose the issue."

```bash
# Step 1: Check if the target pod exists and is Running
kubectl get pod <target-pod> -o wide

# Step 2: Check if there's a service for the target
kubectl get svc <target-service>

# Step 3: Check endpoints (are they populated?)
kubectl get endpoints <target-service>

# Step 4: Test DNS resolution
kubectl run debug --rm -i --restart=Never --image=busybox:1.36 -- \
  nslookup <target-service>.<namespace>.svc.cluster.local

# Step 5: Test connectivity
kubectl run debug --rm -i --restart=Never --image=curlimages/curl -- \
  curl --connect-timeout 5 http://<target-service>.<namespace>.svc.cluster.local

# Step 6: Check network policies
kubectl get networkpolicy -A

# Step 7: Check Cilium endpoints
kubectl -n kube-system exec -it $(kubectl -n kube-system get pods -l k8s-app=cilium -o name | head -1) -- \
  cilium endpoint list
```

## 13.10 Scenario: Backup and Restore

**Request**: "Create a backup of the webapp namespace resources."

```bash
# Export all resources in the namespace
kubectl get all -n webapp -o yaml > /tmp/webapp-backup.yaml

# Export with all resource types
for resource in deployments services pods configmaps secrets pvcs; do
  kubectl get $resource -n webapp -o yaml >> /tmp/webapp-backup-all.yaml
done

# To restore:
kubectl apply -f /tmp/webapp-backup.yaml

# Or selectively:
kubectl get deployments -n webapp -o yaml | kubectl apply -f -
```

## 13.11 Scenario: RBAC — Create a Limited User

**Request**: "Create a service account that can only read pods in the webapp namespace."

```bash
# Create service account
kubectl -n webapp create serviceaccount webapp-viewer

# Create role (read-only)
kubectl -n webapp create role pod-reader \
  --verb=get,list,watch \
  --resource=pods

# Bind role to service account
kubectl -n webapp create rolebinding webapp-viewer-binding \
  --role=pod-reader \
  --serviceaccount=webapp:webapp-viewer

# Test: create a kubeconfig for this user
# (See Appendix for full kubeconfig generation)
```

---

# Stage 14: Expert Scenarios & Advanced Topics

## 14.1 Custom Resource Definitions (CRDs)

Kubernetes is extensible via CRDs. Cilium uses many:

```bash
# List all CRDs
kubectl get crd

# Cilium-specific CRDs
kubectl get crd | grep cilium

# Example: CiliumNetworkPolicy
kubectl get cnp -A
```

## 14.2 Admission Controllers

Kubernetes validates and mutates requests via admission webhooks:

```bash
# List validating webhooks
kubectl get validatingwebhookconfigurations

# List mutating webhooks
kubectl get mutatingwebhookconfigurations
```

## 14.3 Performance Tuning

### Kubernetes API Server

```bash
# Check API server metrics
ssh debian@10.21.10.11 'curl -s https://localhost:6443/metrics --insecure | grep apiserver_request'

# Request latency
ssh debian@10.21.10.11 'curl -s https://localhost:6443/metrics --insecure | grep apiserver_request_duration'
```

### etcd Performance

```bash
# etcd metrics
kubectl -n kube-system exec -it $(kubectl -n kube-system get pods -l component=etcd -o name | head -1) -- \
  etcdctl endpoint health

# etcd stats
kubectl -n kube-system exec -it $(kubectl -n kube-system get pods -l component=etcd -o name | head -1) -- \
  etcdctl endpoint status --write-out=table
```

### Node Resource Pressure

```bash
# Check node conditions
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, conditions: [.status.conditions[] | select(.type=="MemoryPressure" or .type=="DiskPressure" or .type="PIDPressure")]}' 

# Custom metrics
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

## 14.4 Chaos Engineering

### Pod Chaos

```bash
# Randomly kill pods every 30 seconds
while true; do
  POD=$(kubectl get pods -n default -o name | shuf | head -1)
  echo "Killing $POD"
  kubectl delete $POD --grace-period=0 --force
  sleep 30
done
```

### Node Chaos

```bash
# Randomly restart nodes (DANGEROUS — use in lab only)
while true; do
  NODE=$(virsh -c qemu:///system list --name | shuf | head -1)
  echo "Restarting $NODE"
  virsh -c qemu:///system destroy "$NODE"
  sleep 60
  virsh -c qemu:///system start "$NODE"
  sleep 300
done
```

## 14.5 Multi-Cluster Service Mesh

Advanced: connect Cluster A and Cluster B via Cilium ClusterMesh:

```bash
# Enable ClusterMesh on both clusters
cilium clustermesh enable --service-discovery

# Connect clusters
cilium clustermesh connect --destination-context cluster-b

# Verify
cilium clustermesh status
```

## 14.6 Custom Prometheus Rules

```yaml
# Create alert for high pod restarts
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: pod-restart-alert
  namespace: monitoring
spec:
  groups:
  - name: pod-alerts
    rules:
    - alert: PodRestartingTooMuch
      expr: increase(kube_pod_container_status_restarts_total[1h]) > 5
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.pod }} is restarting frequently"
```

## 14.7 Kustomize Overlays

```bash
# Base
mkdir -p kustomize/base
cat > kustomize/base/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:1.27
        ports:
        - containerPort: 80
EOF

# Production overlay
mkdir -p kustomize/production
cat > kustomize/production/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
- ../base
replicas:
- name: webapp
  count: 5
EOF

kubectl apply -k kustomize/production/
```

---

# Troubleshooting Guide

## Common Issues and Solutions

### Issue: kubectl connection refused

```
The connection to the server localhost:8080 was refused
```

**Cause**: KUBECONFIG not set.

**Fix**:
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
# Or for Cluster B:
ssh debian@10.21.20.11 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && kubectl get nodes'
```

### Issue: Pod stuck in Pending

```
NAME         READY   STATUS    RESTARTS   AGE
my-pod-xxx   0/1     Pending   0          5m
```

**Diagnosis**:
```bash
kubectl describe pod my-pod-xxx | grep -A 10 "Events:"
# Common causes:
# - Insufficient resources (CPU/memory)
# - No matching node (nodeAffinity/nodeSelector)
# - PVC not bound
# - Unsatisfiable scheduling constraints
```

**Fix**:
```bash
# Check available resources
kubectl top nodes
kubectl describe node wk01 | grep -A 5 "Allocated resources"

# Check if PVC is bound
kubectl get pvc

# Check node taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

### Issue: Pod in CrashLoopBackOff

```
my-pod-xxx   0/1     CrashLoopBackOff   5 (20s ago)
```

**Diagnosis**:
```bash
# Check logs (current)
kubectl logs my-pod-xxx

# Check logs (previous crashed instance)
kubectl logs my-pod-xxx --previous

# Describe for events
kubectl describe pod my-pod-xxx
```

**Common fixes**:
- Fix application code/configuration
- Fix image name/tag
- Check resource limits (OOMKilled)
- Verify environment variables

### Issue: Pod in ImagePullBackOff

```
my-pod-xxx   0/1     ImagePullBackOff   0
```

**Fix**:
```bash
# Check image name
kubectl get pod my-pod-xxx -o jsonpath='{.spec.containers[0].image}'

# Test image pull manually
docker pull <image-name>

# If private registry, create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass
```

### Issue: Service has no endpoints

```bash
kubectl get endpoints my-service
# ENDPOINTS   <none>
```

**Fix**:
```bash
# Check selector matches pod labels
kubectl get svc my-service -o yaml | grep -A 3 selector
kubectl get pods --show-labels

# Check pods are Running
kubectl get pods -l app=my-app

# Check pod readiness
kubectl describe pod <pod-name> | grep -A 3 "Conditions:"
```

### Issue: PVC stuck in Pending

```bash
kubectl get pvc
# NAME         STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# my-pvc       Pending                                     local-path     5m
```

**Fix**:
```bash
kubectl describe pvc my-pvc
# Check events for errors

# Verify StorageClass exists
kubectl get storageclass

# Check if provisioner is running
kubectl -n kube-system get pods -l app=local-path-provisioner
```

### Issue: Node shows NotReady

```bash
kubectl get nodes
# NAME   STATUS     ROLES                       AGE   VERSION
# wk03   NotReady   <none>                      10m   v1.31.4+k3s1
```

**Diagnosis**:
```bash
# SSH to the node
ssh debian@10.21.10.23

# Check kubelet status
sudo systemctl status k3s-agent

# Check system resources
free -h
df -h

# Check logs
sudo journalctl -u k3s-agent --since "10 minutes ago"
```

### Issue: Cilium pods not ready

```bash
kubectl -n kube-system get pods -l k8s-app=cilium
# NAME           READY   STATUS     RESTARTS   AGE
# cilium-xxxxx   0/1     Init:0/3   0          2m
```

**Fix**:
```bash
# Check Cilium config
kubectl -n kube-system get configmap cilium-config -o yaml

# Check Cilium operator
kubectl -n kube-system get pods -l k8s-app=cilium-operator

# Restart Cilium
kubectl -n kube-system delete pods -l k8s-app=cilium
```

### Issue: DNS resolution fails

```bash
kubectl run test --rm -i --restart=Never --image=busybox:1.36 -- nslookup kubernetes.default
# ** server can't find kubernetes.default: NXDOMAIN
```

**Fix**:
```bash
# Check CoreDNS pods
kubectl -n kube-system get pods -l k8s-app=kube-dns

# Check CoreDNS config
kubectl -n kube-system get configmap coredns -o yaml

# Restart CoreDNS
kubectl -n kube-system rollout restart deployment coredns

# Check /etc/resolv.conf in a pod
kubectl run test --rm -i --restart=Never --image=busybox:1.36 -- cat /etc/resolv.conf
```

### Issue: Port-forward not working from host

```bash
kubectl port-forward svc/my-service 8080:80
# Forwarding from 127.0.0.1:8080 -> 80
# Forwarding from [::1]:8080 -> 80
# curl from host: connection refused
```

**Fix**:
```bash
# Port-forward binds to localhost — use node IP instead
kubectl port-forward --address 0.0.0.0 svc/my-service 8080:80

# Access from host:
curl http://10.21.10.11:8080
```

### Issue: Lab VMs not starting

```bash
virsh -c qemu:///system start wk03-cluster-a
# error: Failed to start domain wk03-cluster-a
# error: internal error: process exited while connecting to monitor
```

**Fix**:
```bash
# Check if base image exists
virsh -c qemu:///system vol-list default

# Check VM definition
virsh -c qemu:///system dumpxml wk03-cluster-a

# Check disk
ls -la /var/lib/libvirt/images/k3s-lab-*

# Recreate VM if needed
cd /mnt/AI/dev/k3slab
./scripts/create-vm.sh wk03 cluster-a 10.21.10.23
```

## Debugging Cheatsheet

| Symptom | First Command | Next Command |
|---------|---------------|--------------|
| Pod Pending | `kubectl describe pod <name>` | `kubectl get events` |
| Pod CrashLoop | `kubectl logs <name> --previous` | `kubectl describe pod <name>` |
| Pod OOMKilled | `kubectl describe pod <name>` | Check resource limits |
| No network | `kubectl -n kube-system get pods -l k8s-app=cilium` | `cilium status` |
| No DNS | `kubectl -n kube-system get pods -l k8s-app=kube-dns` | `kubectl logs -n kube-system -l k8s-app=kube-dns` |
| API unreachable | Check kubeconfig | `systemctl status k3s` |
| Node NotReady | SSH to node, `systemctl status k3s-agent` | `journalctl -u k3s-agent -f` |
| PVC Pending | `kubectl describe pvc <name>` | `kubectl get storageclass` |

---

# Stage 15: Workstation Tools (k9s, kubectx, kubens)

This stage covers essential workstation tools for efficient Kubernetes operations.

## 15.1 Overview of Installed Tools

| Tool | Purpose | Location |
|------|---------|----------|
| **k9s** | Terminal dashboard for K8s | `~/.local/bin/k9s` |
| **kubectx** | Switch kubectl contexts | `~/.local/bin/kubectx` |
| **kubens** | Switch namespaces | `~/.local/bin/kubens` |
| **kubectl** | K8s CLI | `/snap/bin/kubectl` |

## 15.2 PATH Configuration

Add to `~/.zshrc` or `~/.bashrc`:

```bash
# k8s tools (k9s, kubectx, kubens)
export PATH="$HOME/.local/bin:$PATH"
```

Verify installation:

```bash
which k9s kubectx kubens
```

## 15.3 k9s — Terminal Dashboard

### Launch k9s

```bash
k9s
```

### Navigation

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate up/down |
| `Enter` | Select item / drill down |
| `Esc` | Go back one level |
| `:` | Command mode (type command) |
| `/` | Filter/search |
| `Ctrl-C` | Exit k9s |

### Useful Commands in k9s

Press `:` then type:

| Command | Description |
|---------|-------------|
| `pods` | List all pods |
| `deployments` | List all deployments |
| `services` | List all services |
| `nodes` | List all nodes |
| `ns` | List namespaces |
| `rbac` | View RBAC resources |
| `sa` | Service accounts |
| `roles` | Cluster roles |
| `events` | Cluster events |
| `logs` | View logs |
| `describe` | Describe selected resource |

### k9s for RBAC

```bash
# Launch k9s
k9s

# View RBAC resources
: rbac

# View service accounts
: sa

# View cluster roles
: clusterroles

# View cluster role bindings
: clusterrolebindings
```

### k9s for Debugging

```bash
# Launch k9s
k9s

# Filter pods by namespace
/ <namespace>

# View pod logs
l

# Execute into pod
s

# Describe pod
d

# View pod YAML
y

# View pod events
e
```

### k9s Multi-Cluster

```bash
# Switch context in k9s
k9s --context cluster-a
k9s --context cluster-b

# Or use Ctrl-A to switch contexts while k9s is running
```

## 15.4 kubectx — Context Switching

### List Contexts

```bash
kubectx
# Output:
# cluster-a
# cluster-b
```

### Switch Context

```bash
kubectx cluster-a
# Switched to context "cluster-a"

kubectx cluster-b
# Switched to context "cluster-b"
```

### Rename Context

```bash
kubectx cluster-a=production
```

### Delete Context

```bash
kubectx -d old-context
```

### Use with kubectl

```bash
# Current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Use specific context
kubectl --context=cluster-a get pods
```

## 15.5 kubens — Namespace Switching

### List Namespaces

```bash
kubens
# Output:
# argocd
# cilium-secrets
# default
# headlamp
# kube-node-lease
# kube-public
# kube-system
# monitoring
```

### Switch Namespace

```bash
kubens monitoring
# Switched to namespace "monitoring"

kubens kube-system
# Switched to namespace "kube-system"

kubens default
# Switched to namespace "default"
```

### Use with kubectl

```bash
# Set namespace for current context
kubectl config set-context --current --namespace=monitoring

# Use namespace flag
kubectl -n monitoring get pods
kubectl -n kube-system get pods
```

## 15.6 Common Workflows

### Workflow 1: Quick Cluster Check

```bash
# Check current context and namespace
kubectx
kubens

# View all pods
kubens
# Select a namespace
kubectl get pods
```

### Workflow 2: Debug Pod Issues

```bash
# Launch k9s
k9s

# Find namespace
: ns
# Select namespace

# Find pod
/ pod-name

# View logs
l

# Execute into pod
s
```

### Workflow 3: RBAC Audit

```bash
# Launch k9s
k9s

# View RBAC
: rbac

# Or use kubectl
kubectl auth can-i --list
kubectl auth can-i create pods -n monitoring
```

### Workflow 4: Multi-Cluster Operations

```bash
# Switch to cluster-a
kubectx cluster-a
kubens default

# Check nodes
kubectl get nodes

# Switch to cluster-b
kubectx cluster-b
kubens default

# Check nodes
kubectl get nodes
```

## 15.7 Headlamp — Web UI

Headlamp is deployed on Cluster A for visual cluster management.

### Access

- **URL**: `http://10.21.10.11:32437`
- **Login**: Use token (see `kubectl create token headlamp -n headlamp`)

### Features

- Visual pod/deployment management
- RBAC viewer
- Resource usage graphs
- Log viewer
- Event viewer

### Create Login Token

```bash
# Generate new token
kubectl create token headlamp -n headlamp --duration=87600h

# Or get existing token
kubectl -n headlamp get secret headlamp -o jsonpath='{.data.token}' | base64 -d
```

---

# Reference Appendix

## A. IP Address Map

| Node | Cluster | IP | Role |
|------|---------|-----|------|
| cp01-cluster-a | A | 10.21.10.11 | Control Plane |
| cp02-cluster-a | A | 10.21.10.12 | Control Plane |
| cp03-cluster-a | A | 10.21.10.13 | Control Plane |
| wk01-cluster-a | A | 10.21.10.21 | Worker |
| wk02-cluster-a | A | 10.21.10.22 | Worker |
| wk03-cluster-a | A | 10.21.10.23 | Worker |
| cp01-cluster-b | B | 10.21.20.11 | Control Plane |
| cp02-cluster-b | B | 10.21.20.12 | Control Plane |
| cp03-cluster-b | B | 10.21.20.13 | Control Plane |
| wk01-cluster-b | B | 10.21.20.21 | Worker |
| wk02-cluster-b | B | 10.21.20.22 | Worker |
| wk03-cluster-b | B | 10.21.20.23 | Worker |

## B. Credentials

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| SSH (all VMs) | `ssh debian@<IP>` | debian | (see terraform.tfvars) |
| SSH (root) | `ssh root@<IP>` | root | (see terraform.tfvars) |
| Argo CD (A) | `http://10.21.10.11:8080` | admin | (see terraform.tfvars) |
| Argo CD (B) | `http://10.21.20.11:8080` | admin | (see terraform.tfvars) |
| Grafana (A) | `http://10.21.10.11:3000` | admin | (set in terraform.tfvars) |
| Grafana (B) | `http://10.21.20.11:3000` | admin | (set in terraform.tfvars) |
| Prometheus (A) | `http://10.21.10.11:9090` | — | — |
| Prometheus (B) | `http://10.21.20.11:9090` | — | — |

## C. Network Ranges

| Network | CIDR | Purpose |
|---------|------|---------|
| Host LAN | 192.168.0.0/24 | Physical host internet |
| Cluster A | 10.21.10.0/24 | Cluster A nodes |
| Cluster B | 10.21.20.0/24 | Cluster B nodes |
| Pod CIDR | 10.44.0.0/16 | Cilium pod IPs |
| Service CIDR | 10.45.0.0/16 | Kubernetes Service VIPs |

## D. K3s Configuration Flags

```bash
# Server (first node)
--cluster-init                           # Initialize embedded etcd cluster
--flannel-backend=none                   # Disable Flannel (Cilium replaces it)
--disable-network-policy                 # Cilium handles network policy
--disable=traefik                        # No ingress controller
--disable=servicelb                      # No load balancer
--disable=local-storage                  # Use local-path-provisioner instead
--tls-san="<api_vip>"                    # Add VIP to TLS certificate
--write-kubeconfig-mode=0644             # Allow read access to kubeconfig
--node-ip="<node_ip>"                    # Advertise this node's IP
--cluster-cidr="10.44.0.0/16"           # Pod network CIDR
--service-cidr="10.45.0.0/16"           # Service network CIDR
--token="<cluster_token>"                # Shared secret for cluster join

# Agent (worker)
--server="https://<api_vip>:6443"        # Connect to API server
--token="<cluster_token>"                # Shared secret for cluster join
--node-ip="<node_ip>"                    # Advertise this node's IP
```

## E. Helm Chart Versions

| Chart | Version | Repository |
|-------|---------|------------|
| Cilium | 1.17.6 | cilium |
| Argo CD | 3.5.2 | argo |
| kube-prometheus-stack | latest | prometheus-community |

## F. File Locations

| File | Purpose |
|------|---------|
| `/mnt/AI/dev/k3slab/` | Lab root |
| `/mnt/AI/dev/k3slab/scripts/lab-power.sh` | VM power management |
| `/mnt/AI/dev/k3slab/scripts/failure-test.sh` | Failure testing |
| `/mnt/AI/dev/k3slab/tofu/` | OpenTofu infrastructure |
| `/mnt/AI/dev/k3slab/gitops/` | GitOps manifests |
| `/mnt/AI/dev/k3slab/docs/` | Documentation |
| `/etc/rancher/k3s/k3s.yaml` | K3s kubeconfig (inside VMs) |
| `/home/ben/.ssh/id_ed25519` | SSH key for lab access |

## G. Useful One-Liners

```bash
# Get all pods with their node assignment
kubectl get pods -A -o custom-columns='NAMESPACE:metadata.namespace,NAME:metadata.name,NODE:spec.nodeName,STATUS:status.phase'

# Find pods using more than 100Mi memory
kubectl top pods -A --sort-by=memory | awk '$3 > 100 {print}'

# Count pods per namespace
kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c | sort -rn

# Find all LoadBalancer/NodePort services
kubectl get svc -A --field-selector spec.type!=ClusterIP

# Watch for pod restarts
kubectl get pods -A --watch-only | grep -v Running

# Get node external IPs (for NodePort access)
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'

# Delete all Evicted pods
kubectl get pods -A | grep Evicted | awk '{print $1, $2}' | xargs -L1 kubectl delete pod

# Force delete stuck pods
kubectl get pods -A --field-selector=status.phase=Failed -o name | xargs kubectl delete --grace-period=0 --force
```

## H. Cheat Sheet: kubectl Aliases

Add to `~/.bashrc`:

```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgn='kubectl get nodes'
alias kgs='kubectl get svc'
alias kgnn='kubectl get namespaces'
alias kdp='kubectl describe pod'
alias kdn='kubectl describe node'
alias klp='kubectl logs -f'
alias kex='kubectl exec -it'
alias ka='kubectl apply -f'
alias kd='kubectl delete -f'
alias kdf='kubectl delete --grace-period=0 --force'
```

---

*This manual is a living document. As the lab evolves, update the relevant sections.*
