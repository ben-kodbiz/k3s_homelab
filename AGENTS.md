# AGENTS.md

## What this repo is

K3s Kubernetes lab — a resource-consumption experiment comparing K3s vs raw Kubernetes. The existing raw K8s lab lives at `/mnt/AI/dev/k8s/`. This repo builds a parallel K3s environment for apples-to-apples comparison.

## Hard safety rules

- **NEVER touch** `/mnt/AI/dev/k8s/` — no VMs, disks, config, networking, or state
- **NEVER modify host networking** — no bridges on physical NIC, no NetworkManager changes, no firewall changes
- **Audit storage before provisioning** — check `df -h`, `virsh pool-list --all`, and existing disk locations before creating anything
- New lab lives at `/mnt/AI/dev/k8s-k3s/` with independent state

## Build order

Follow this sequence — validate at each stage before proceeding:

1. Audit existing lab (`/mnt/AI/dev/k8s/`)
2. Storage audit (`df -h`, `virsh pool-list`, find existing disks)
3. Network design (separate libvirt NAT, no overlap with existing)
4. Infrastructure (OpenTofu + libvirt + cloud-init)
5. K3s bootstrap (pinned version, disable Flannel/Traefik/ServiceLB)
6. Cilium CNI (mandatory — replaces Flannel)
7. Helm
8. Argo CD + GitOps
9. Storage (PVC/PV)
10. Monitoring (lightweight — no Trivy during baseline)
11. Baseline resource measurement
12. Workloads
13. Failure testing
14. Resource comparison report

## Key constraints

- **Cilium is mandatory** — not Flannel. K3s must be configured for external CNI
- **Disable K3s defaults** that conflict: Flannel, Traefik, ServiceLB, local-storage (document each)
- **Pin K3s version** — never use `latest`
- **Two real clusters** (A + B), each with 3 server nodes + workers — independently addressable
- **No Trivy** during initial build — resource consumption is the experiment
- **Idempotent scripts** — every stage safe to rerun; destructive ops require `--confirm`
- **Don't overallocate** — host is resource-constrained (Ryzen 5 5600G / 64GB), check free capacity first

## Technology stack

OpenTofu, libvirt, cloud-init, K3s, Cilium, Helm, Argo CD, Prometheus/Grafana (if needed)

## Reference lab

`/mnt/AI/dev/k8s/` is the control group. Inspect it first to understand the existing architecture before writing any deployment code.
