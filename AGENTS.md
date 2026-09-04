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

## CRITICAL LESSONS LEARNED

### NEVER use `tofu apply` to change VM CPU/RAM — use `virsh` instead

**The Mistake:** Running `tofu apply` to change `control_plane_vcpu` or `control_plane_memory_mb` DESTROYS and RECREATES all VMs (because `null_resource.vm` has triggers on user_data). This wipes K3s, Cilium, Helm, Argo CD, Rancher — everything.

**The Correct Way:** Change running VM resources live with `virsh`:
```bash
# Stop the VM first
virsh -c qemu:///system shutdown <vm-name>

# Change vCPUs (must be <= maxvcpus defined in XML)
virsh -c qemu:///system setvcpus <vm-name> <new-count> --config

# Change RAM (in KiB)
virsh -c qemu:///system setmem <vm-name> <new-mem-kiB> --config

# Start the VM
virsh -c qemu:///system start <vm-name>
```

This preserves all K3s/Rancher state — only the hardware allocation changes.

### Do NOT use `tofu apply -target=module.cluster_a` as a workaround

Targeting still triggers full destroy/recreate of the targeted module because tofu detects user_data content changes (even if only the vm_password template variable changed). This caused a full rebuild of Cluster A when we only meant to change resources.

### Always verify seed ISO content before blaming cloud-init

If VMs have no IPs after recreation, check:
1. `virsh net-dhcp-leases k3s-lab-net` — are there DHCP leases?
2. Mount the seed ISO and verify `network-config` file exists inside
3. Check if the interface name in network-config matches what the VM actually sees (`ip link show` via console)
