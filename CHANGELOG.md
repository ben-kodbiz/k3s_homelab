# K3s Lab Changelog

## [Unreleased]

### Phase 0-1: Foundation
- Created directory structure
- OpenTofu modules: libvirt-network, linux-vm, cluster-node, k3s-cluster
- Cloud-init templates for K3s server and agent nodes
- Scripts: preflight, host-network-check, create-vm, delete-vm, destroy, validate
- Network: k3s-lab-net on 10.21.0.0/16 (separate from existing 10.20.0.0/16)
- K3s version pinned: v1.31.4+k3s1
- Disabled defaults: Flannel, Traefik, ServiceLB, local-storage
- Cilium CNI configured
