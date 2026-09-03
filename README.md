# K3s Kubernetes Lab

Resource consumption experiment comparing K3s vs raw Kubernetes.

## Architecture

```
                    HOST (Ryzen 5 5600G / 64GB)
                             │
                        Ubuntu Linux
                             │
                        KVM / QEMU + libvirt
                             │
                     ┌───────┴───────┐
                     │               │
              Existing Lab       K3s Lab
              Raw Kubernetes     Experiment
              10.20.0.0/16       10.21.0.0/16
                     │               │
                Cluster A+B     Cluster A+B
                (kubeadm)       (K3s + Cilium)
                     │               │
                     └───────┬───────┘
                             │
                    Resource Comparison
                    CPU / RAM / Temp / Disk
```

## Network

| Network | CIDR | Purpose |
|---------|------|---------|
| k8s-lab-net | 10.20.0.0/16 | Existing raw K8s lab (DO NOT TOUCH) |
| k3s-lab-net | 10.21.0.0/16 | New K3s experiment |
| Pod CIDR | 10.42.0.0/16 | K3s pods (Cilium) |
| Service CIDR | 10.43.0.0/16 | K3s services |

## Quick Start

```bash
# 1. Preflight checks (read-only)
./scripts/preflight.sh

# 2. Create network + base image
cd tofu/environments && tofu init && tofu apply -var-file=lab.tfvars

# 3. Create Cluster A
tofu apply -var-file=cluster-a.tfvars

# 4. Set up kubeconfig
# On first server node:
#   cat /etc/rancher/k3s/k3s.yaml
# Or retrieve from libvirt:
#   virsh console cp01-cluster-a
```

## K3s vs Raw K8s Differences

| Component | Raw K8s | K3s Lab |
|-----------|---------|---------|
| Bootstrap | kubeadm | K3s single binary |
| CNI | Cilium | Cilium (Flannel disabled) |
| API HA | kube-vip | Built-in (embedded etcd) |
| Traefik | Enabled | Disabled |
| ServiceLB | Enabled | Disabled |
| Local storage | Enabled | Disabled |
| Containerd | System | Bundled with K3s |

## Directory Structure

```
k3slab/
├── tofu/              # OpenTofu infrastructure
│   ├── modules/       # Reusable modules
│   │   ├── libvirt-network/
│   │   ├── linux-vm/
│   │   ├── cluster-node/
│   │   └── k3s-cluster/
│   └── environments/  # tfvars per stage
├── scripts/           # Preflight, validate, destroy
├── cloud-init/        # Reference cloud-init templates
├── kubernetes/        # K8s manifests (post-bootstrap)
├── gitops/            # Argo CD structure
├── docs/              # Architecture docs
├── scenarios/         # Failure test runbooks
└── tests/             # Validation scripts
```
