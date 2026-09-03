# Architecture

## Design Principles

1. **Isolation**: K3s lab network (`10.21.0.0/16`) is completely separate from the existing raw K8s lab (`10.20.0.0/16`)
2. **Reproducibility**: OpenTofu manages all infrastructure; destroy and rebuild from Git
3. **Comparison**: Same host, same hardware, different Kubernetes distribution — apples-to-apples resource measurement
4. **Safety**: Never modify host networking, existing lab, or physical NIC

## K3s Configuration

K3s is configured with these defaults disabled:
- **Flannel** — replaced by Cilium
- **Traefik** — not needed for resource comparison
- **ServiceLB** — not needed for resource comparison
- **Local storage** — use external storage

## Cluster Topology

Each cluster (A and B):
- 3 server nodes (control plane + embedded etcd)
- 3 agent nodes (workers)
- Independent kubeconfig
- Cilium CNI

## Addressing Scheme

| Node | Cluster A | Cluster B |
|------|-----------|-----------|
| API VIP | 10.21.10.10 | 10.21.20.10 |
| CP01 | 10.21.10.11 | 10.21.20.11 |
| CP02 | 10.21.10.12 | 10.21.20.12 |
| CP03 | 10.21.10.13 | 10.21.20.13 |
| WK01 | 10.21.10.21 | 10.21.20.21 |
| WK02 | 10.21.10.22 | 10.21.20.22 |
| WK03 | 10.21.10.23 | 10.21.20.23 |
