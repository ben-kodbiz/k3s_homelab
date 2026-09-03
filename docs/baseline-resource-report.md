# K3s Lab — Baseline Resource Report

## Host System

| Component | Value |
|-----------|-------|
| CPU | AMD Ryzen 5 5600G (6C/12T) |
| RAM | 64GB (19GB used, 43GB available) |
| Disk | 901GB NVMe (464GB used, 392GB available) |
| Temperature | 40-60°C |
| Load Average | 2.80, 3.26, 2.72 |

## Cluster A — K3s + Cilium + Argo CD + Monitoring

### Node Resource Usage (with workloads)

| Node | CPU (millicores) | CPU % | Memory (MiB) | Memory % |
|------|----------------:|------:|-------------:|---------:|
| cp01 (control-plane) | 170m | 8% | 1485Mi | 77% |
| cp02 (control-plane) | 145m | 7% | 1290Mi | 67% |
| cp03 (control-plane) | 289m | 14% | 1431Mi | 74% |
| wk01 (worker) | 71m | 3% | 976Mi | 69% |
| wk02 (worker) | 68m | 3% | 599Mi | 42% |
| wk03 (worker) | 34m | 1% | 660Mi | 46% |

### Total Cluster Usage

| Metric | Value |
|--------|-------|
| Total CPU | ~777m (6.5% of 12 cores) |
| Total Memory | ~6441Mi (~10GB) |
| Running Pods | 40 |
| Host RAM Used | 19GB / 64GB (30%) |

### Component Overhead

| Component | CPU (millicores) | Memory (MiB) | Pods |
|-----------|----------------:|-------------:|-----:|
| Cilium | 95m | 1002Mi | 6 |
| Cilium Envoy | 13m | 148Mi | 6 |
| Cilium Operator | 3m | 55Mi | 1 |
| CoreDNS | 2m | 17Mi | 1 |
| Metrics Server | 3m | 25Mi | 1 |
| Argo CD | 10m | 222Mi | 7 |
| Prometheus stack | ~50m | ~800Mi | 11 |
| local-path-provisioner | 1m | 10Mi | 1 |
| **Platform total** | **~177m** | **~2279Mi** | **34** |
| Workloads (nginx+httpbin) | ~10m | ~384Mi | 6 |

## Installed Components

| Component | Version | Status |
|-----------|---------|--------|
| K3s | v1.31.4+k3s1 | Running |
| Cilium | 1.17.6 | Healthy |
| Helm | v3.21.4 | Installed |
| Argo CD | v3.5.2 | Running |
| Prometheus | latest | Running |
| Grafana | latest | Running |
| local-path-provisioner | v0.0.31 | Running |
| CoreDNS | built-in | Running |
| Metrics Server | built-in | Running |

## Access URLs (from host)

| Service | URL | Credentials |
|---------|-----|-------------|
| Argo CD | http://10.21.10.11:8080 | admin / (see terraform.tfvars) |
| Grafana | http://10.21.10.11:3000 | admin / (see terraform.tfvars) |
| Prometheus | http://10.21.10.11:9090 | - |

## Disabled K3s Components

| Component | Reason | Replacement |
|-----------|--------|-------------|
| Flannel | Replaced by Cilium | Cilium CNI |
| Traefik | Not needed for experiment | None (use NodePort) |
| ServiceLB | Not needed for experiment | None (use NodePort) |
| local-storage | Replaced by external provisioner | local-path-provisioner |

## SSH Access

All VMs: `ssh -i /home/ben/.ssh/id_ed25519 debian@<IP>`
Password: (set in `terraform.tfvars` as `vm_password`, for both `debian` and `root`)

| Node | IP |
|------|-----|
| cp01 | 10.21.10.11 |
| cp02 | 10.21.10.12 |
| cp03 | 10.21.10.13 |
| wk01 | 10.21.10.21 |
| wk02 | 10.21.10.22 |
| wk03 | 10.21.10.23 |

## kubectl Access

```bash
ssh -i /home/ben/.ssh/id_ed25519 debian@10.21.10.11
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
kubectl get pods -A
```
