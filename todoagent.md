# K3s Kubernetes Lab — Build TODO

## 0. Mission

Build a **second Kubernetes laboratory** using **K3s**, based on the architecture and capabilities of the existing lab:

```text
/mnt/AI/dev/k8s/
```

The purpose of this lab is **not merely to create another Kubernetes cluster**.

The primary experiment is:

> **Measure whether K3s consumes materially fewer CPU/RAM resources than the existing raw Kubernetes implementation under equivalent workloads and components.**

The resulting environment must allow an apples-to-apples comparison between:

```text
Existing Lab
Raw Kubernetes
     VS
New Lab
K3s + Cilium
```

The new environment must contain:

* Cluster A
* Cluster B
* HA-capable architecture
* Cilium CNI
* Helm
* Argo CD
* GitOps structure
* persistent storage
* monitoring/metrics required for resource comparison
* realistic Kubernetes workloads
* failure/testing scenarios

Do **NOT** add Trivy or other heavy security tooling during the initial build. Resource consumption is the experiment.

---

# 1. HARD SAFETY REQUIREMENTS

## 1.1 Existing lab MUST NOT be damaged

Before modifying anything:

```bash
cd /mnt/AI/dev/k8s/
```

Inspect the existing repository.

The new K3s lab must be isolated from the existing raw Kubernetes lab.

Do not:

* delete existing VMs
* delete existing disks
* modify existing Kubernetes configuration
* modify existing CNI configuration
* modify host networking
* modify physical NIC configuration
* modify existing libvirt networks
* overwrite existing Terraform/OpenTofu state
* reuse an existing disk until it has been positively identified as safe

The existing lab is the control/reference environment.

---

# 2. FIRST TASK — AUDIT EXISTING LAB

Before writing deployment code, inspect:

```text
/mnt/AI/dev/k8s/
```

Determine:

* directory structure
* OpenTofu/Terraform configuration
* libvirt configuration
* VM definitions
* VM disk locations
* disk sizes
* CPU allocation
* RAM allocation
* network configuration
* Kubernetes version
* CNI
* Helm configuration
* Argo CD
* monitoring
* storage
* namespaces
* workloads
* Cluster A architecture
* Cluster B architecture
* scripts
* configuration files
* documentation

Generate:

```text
docs/existing-lab-audit.md
```

containing a concise inventory.

Do not assume the previous design from memory is still exactly correct. Inspect the actual repository.

---

# 3. STORAGE AUDIT — MUST HAPPEN BEFORE CREATION

The host has limited SSD capacity.

Before creating any disk:

```bash
df -h
df -h /mnt/AI/dev/k8s/
df -h /var/lib/libvirt/
```

Also inspect:

```bash
virsh pool-list --all
virsh pool-info <pool>
virsh vol-list <pool>
```

Find all existing VM disks:

```bash
find /var/lib/libvirt -type f \
  \( -name '*.qcow2' -o -name '*.raw' -o -name '*.img' \) \
  -ls
```

Determine:

1. Available host storage.
2. Existing K8s disk allocations.
3. Whether an existing disk/volume can safely be reused.
4. Whether the disk belongs to the existing raw Kubernetes lab.
5. Whether reusing it would destroy or corrupt anything.
6. Whether sufficient free space exists for Cluster A + Cluster B.

## Reuse policy

### SAFE TO REUSE

Reuse existing storage **only if**:

* it is not currently attached to the existing lab,
* it contains no required data,
* its ownership/purpose is known,
* it can be safely repurposed,
* and doing so does not modify the existing lab.

### NOT SAFE

Do NOT reuse:

```text
etcd disks
active Kubernetes node disks
active VM root disks
active PV disks
active libvirt volumes
existing cluster state
```

unless the deployment explicitly provisions them as disposable/reusable resources.

If safe reusable capacity exists:

> USE IT.

If not:

> CREATE NEW STORAGE.

Never blindly create additional storage before checking available capacity.

Document the decision in:

```text
docs/storage-decision.md
```

---

# 4. NEW LAB DIRECTORY

Do NOT mix the new K3s configuration into the existing raw-Kubernetes deployment state.

Preferred structure:

```text
/mnt/AI/dev/k8s-k3s/
```

If the existing repository already contains an appropriate modular structure for multiple distributions, use it instead, but maintain completely independent state.

Suggested:

```text
k8s-k3s/
├── README.md
├── todoagent.md
├── docs/
├── tofu/
├── cloud-init/
├── scripts/
├── clusters/
│   ├── cluster-a/
│   └── cluster-b/
├── helm/
├── gitops/
└── tests/
```

---

# 5. NETWORK ISOLATION

The host network MUST remain untouched.

Do NOT:

* create bridges on the physical NIC
* modify NetworkManager host interfaces
* modify host routing
* modify host firewall rules unnecessarily
* attach Kubernetes directly to the physical LAN

Use isolated libvirt networking consistent with the existing lab.

Create a **separate network namespace/network segment for the K3s experiment**.

Example:

```text
Physical LAN
     │
     X
     │
     └── MUST NOT BE MODIFIED
     
Host
 │
 └── libvirt NAT
       │
       └── K3s Lab Network
             ├── Cluster A
             └── Cluster B
```

The exact subnet must be selected after inspecting existing networks to prevent overlap.

Document:

```text
docs/network-design.md
```

---

# 6. CLUSTER DESIGN

Create:

```text
Cluster A
Cluster B
```

The architecture should resemble the existing raw Kubernetes lab as closely as practical.

## Cluster A

Target:

```text
3 K3s server/control-plane nodes
+
worker node(s)
```

## Cluster B

Target:

```text
3 K3s server/control-plane nodes
+
worker node(s)
```

However:

> Do not blindly allocate resources until the host capacity has been measured.

The objective is maximum useful Kubernetes density without destabilizing the host.

If necessary, use smaller VM allocations while preserving the topology and HA experiment.

---

# 7. K3S CONFIGURATION

Use a pinned K3s version.

Do not install arbitrary `latest`.

Record:

```text
K3s version
Kubernetes version
container runtime
kernel
OS
```

K3s defaults that conflict with the experiment must be disabled.

At minimum investigate and configure:

```text
Flannel
Traefik
ServiceLB
CoreDNS
kube-proxy
local-storage
metrics-server
```

Do not assume every component should be disabled.

For every disabled component document:

```text
Component
Reason
Replacement
```

---

# 8. CNI — CILIUM

This is mandatory.

The lab must use:

```text
K3s + Cilium
```

NOT:

```text
K3s + Flannel
```

Configure K3s correctly for external CNI usage.

Verify:

```bash
kubectl get pods -A
kubectl get nodes
kubectl get ciliumnodes
cilium status
```

Cilium must become the actual networking layer.

Test:

```text
pod → pod
pod → service
pod → DNS
pod → external network
cross-node pod communication
```

Document:

```text
docs/cilium.md
```

---

# 9. CILIUM FEATURES

Start with a lightweight baseline.

Do not enable every Cilium feature simply because it exists.

Required:

* CNI
* network policy
* service connectivity
* observability sufficient for troubleshooting

Hubble may be enabled if resource consumption remains reasonable.

Record its resource impact.

The experiment must distinguish:

```text
K3s overhead
Cilium overhead
Argo CD overhead
Monitoring overhead
Application workload
```

---

# 10. HELM

Install/configure Helm.

Helm must be used for application deployment where appropriate.

Verify:

```bash
helm version
helm list -A
```

Create at least one small lab chart to reproduce the existing lab's Helm workflow.

---

# 11. ARGO CD / GITOPS

Install Argo CD.

The GitOps structure should mirror the existing lab where practical.

Target:

```text
Git repository
      │
      ▼
   Argo CD
      │
      ├── Cluster A
      │
      └── Cluster B
```

Avoid unnecessarily heavy GitOps applications.

Verify:

```text
Git change
   ↓
Argo CD detects change
   ↓
Cluster synchronizes
   ↓
Workload updated
```

Document:

```text
docs/gitops.md
```

---

# 12. STORAGE

Use the lightest storage implementation that provides useful Kubernetes storage testing.

Prefer the same conceptual storage model as the existing lab so the resource comparison remains meaningful.

Test:

```text
PVC creation
PV binding
pod writing data
pod restart
pod rescheduling
data persistence
```

Do not accidentally use an existing production/reference PV.

---

# 13. MONITORING

Monitoring is required because resource consumption is the experiment.

At minimum collect:

```text
CPU
RAM
node load
pod CPU
pod RAM
VM CPU
VM RAM
disk usage
```

Use lightweight tooling where possible.

Do NOT install Trivy during the baseline experiment.

If Prometheus/Grafana already exists in the reference architecture, determine whether duplicating it materially distorts the experiment.

If necessary:

```text
Baseline test
    ↓
minimal monitoring

Extended test
    ↓
full monitoring
```

Record both results.

---

# 14. BASELINE RESOURCE MEASUREMENT

Before deploying application workloads:

## Host

Record:

```bash
lscpu
free -h
df -h
uptime
```

Record CPU temperature if available:

```bash
sensors
```

Record VM resource allocation:

```bash
virsh list --all
virsh dominfo <vm>
```

Record host CPU utilization while:

```text
Cluster A only
Cluster B only
Cluster A + B
```

---

# 15. COMPONENT-BY-COMPONENT MEASUREMENT

Measure incrementally.

### Test 1

```text
K3s Cluster A
```

Record:

```text
idle CPU
RAM
temperature
load
```

### Test 2

```text
Cluster A + Cluster B
```

Record the same.

### Test 3

```text
+ Cilium
```

Record the same.

### Test 4

```text
+ Helm workloads
```

### Test 5

```text
+ Argo CD
```

### Test 6

```text
+ monitoring
```

### Test 7

```text
+ realistic applications
```

This allows identification of the actual CPU consumer.

---

# 16. REFERENCE-LAB COMPARISON

Compare against:

```text
/mnt/AI/dev/k8s/
```

Create:

```text
docs/resource-comparison.md
```

Table:

| Configuration    | CPU | RAM | Temp | Notes |
| ---------------- | --: | --: | ---: | ----- |
| Raw K8s A        |     |     |      |       |
| Raw K8s A+B      |     |     |      |       |
| K3s A            |     |     |      |       |
| K3s A+B          |     |     |      |       |
| K3s + Cilium     |     |     |      |       |
| K3s + Argo CD    |     |     |      |       |
| K3s + Monitoring |     |     |      |       |
| Full K3s lab     |     |     |      |       |

Use actual measured numbers.

Do not claim K3s is more efficient based on assumptions.

---

# 17. TEMPERATURE EXPERIMENT

The previous lab demonstrated a major temperature change when Cluster B was disabled.

Reproduce the experiment.

Measure:

```text
Raw K8s:

A enabled
A+B enabled
B disabled
```

Then:

```text
K3s:

A enabled
A+B enabled
B disabled
```

Compare.

The objective is to answer:

> Does K3s reduce the CPU load responsible for the thermal increase?

Do not confuse:

```text
CPU utilization
```

with:

```text
CPU temperature
```

Record both.

---

# 18. FAILURE TESTING

After baseline measurements are complete, test:

### Node failure

```text
stop one server node
```

Verify cluster behavior.

### Worker failure

```text
stop one worker
```

Verify workload recovery.

### Cilium failure

Test controlled Cilium disruption.

### DNS failure

Test DNS troubleshooting.

### Pod failure

Delete application pods.

### Deployment failure

Introduce a bad deployment.

### GitOps rollback

Revert the Git change through Argo CD.

### Storage failure

Test pod/PVC behavior.

Document every scenario.

---

# 19. CLUSTER B MUST REMAIN A REAL SECOND CLUSTER

Do not create Cluster B merely as duplicate VMs.

It must be independently addressable and independently controllable.

Verify:

```text
Cluster A context
Cluster B context
```

Example:

```bash
kubectl config get-contexts
```

Ensure commands cannot accidentally target the wrong cluster.

---

# 20. RESOURCE BUDGET

The host is resource constrained.

Do not overallocate resources simply because Kubernetes reports that they are available.

Before provisioning calculate:

```text
Host RAM
- existing host requirement
- existing raw K8s lab requirement
- K3s allocation
= remaining RAM
```

Likewise CPU and disk.

The build must stop safely if there is insufficient storage.

Do NOT:

```text
fill filesystem to 100%
```

Maintain reasonable free space.

---

# 21. AUTOMATION

The deployment must be reproducible.

Prefer:

```text
OpenTofu
+
libvirt
+
cloud-init
+
K3s
+
Cilium
+
Helm
+
Argo CD
```

Avoid a giant monolithic shell script.

Separate:

```text
infrastructure
cluster bootstrap
CNI
platform services
GitOps
tests
```

---

# 22. IDEMPOTENCY

Every stage should be safe to rerun.

Examples:

```bash
./bootstrap.sh
./install-cilium.sh
./install-argocd.sh
./test.sh
```

Running a completed stage again should not destroy the environment.

Where destructive operations are unavoidable, require an explicit flag.

Example:

```bash
./destroy.sh --confirm
```

---

# 23. VALIDATION CHECKPOINTS

After each stage, stop and validate.

## Infrastructure

```text
[ ] network exists
[ ] storage exists
[ ] VMs boot
[ ] SSH works
```

## K3s

```text
[ ] all server nodes ready
[ ] workers ready
[ ] Kubernetes API works
[ ] no unexpected CrashLoopBackOff
```

## Cilium

```text
[ ] Cilium healthy
[ ] nodes connected
[ ] pod networking works
[ ] DNS works
```

## Helm

```text
[ ] Helm works
[ ] test chart deploys
```

## Argo CD

```text
[ ] Argo CD healthy
[ ] Git repository reachable
[ ] application sync works
```

## Storage

```text
[ ] PVC binds
[ ] application writes data
[ ] data survives pod restart
```

---

# 24. FINAL TEST MATRIX

Produce:

```text
tests/results.md
```

Containing:

| Test               | Cluster A | Cluster B | Result |
| ------------------ | --------- | --------- | ------ |
| API                |           |           |        |
| Node readiness     |           |           |        |
| Cilium             |           |           |        |
| DNS                |           |           |        |
| Pod networking     |           |           |        |
| Service networking |           |           |        |
| Helm               |           |           |        |
| Argo CD            |           |           |        |
| PVC                |           |           |        |
| Node failure       |           |           |        |
| Worker failure     |           |           |        |
| GitOps rollback    |           |           |        |

---

# 25. FINAL RESOURCE REPORT

Produce:

```text
docs/final-resource-report.md
```

Answer these questions using measured data:

1. How much RAM does raw Kubernetes consume?
2. How much RAM does K3s consume?
3. How much CPU does raw Kubernetes consume?
4. How much CPU does K3s consume?
5. What is the idle CPU difference?
6. What is the CPU difference with two clusters?
7. What is the Cilium overhead?
8. What is the Argo CD overhead?
9. What is the monitoring overhead?
10. Which component is actually responsible for high CPU?
11. Does K3s reduce host temperature?
12. How many additional nodes/pods can the host support with K3s?

Do not manufacture numbers.

---

# 26. SUCCESS CRITERIA

The project is complete only when:

```text
[ ] Existing raw Kubernetes lab remains untouched
[ ] Storage was audited before provisioning
[ ] Existing reusable storage was used where safe
[ ] New storage was created only when necessary
[ ] Host network remains untouched
[ ] Cluster A exists
[ ] Cluster B exists
[ ] K3s is running
[ ] Flannel is NOT the CNI
[ ] Cilium is the CNI
[ ] Helm works
[ ] Argo CD works
[ ] GitOps works
[ ] Storage works
[ ] Monitoring works
[ ] HA/failure scenarios work
[ ] CPU measurements collected
[ ] RAM measurements collected
[ ] temperature measurements collected
[ ] Raw K8s vs K3s comparison completed
[ ] Documentation completed
```

---

# 27. IMPORTANT AGENT BEHAVIOR

Do not blindly execute the entire deployment in one step.

Work in stages:

```text
AUDIT
  ↓
STORAGE CHECK
  ↓
NETWORK DESIGN
  ↓
INFRASTRUCTURE
  ↓
K3S
  ↓
CILIUM
  ↓
HELM
  ↓
ARGO CD
  ↓
STORAGE
  ↓
MONITORING
  ↓
BASELINE MEASUREMENT
  ↓
WORKLOADS
  ↓
FAILURE TESTS
  ↓
RESOURCE COMPARISON
```

At every stage:

1. Inspect.
2. Change.
3. Validate.
4. Record results.
5. Only then continue.

If something fails, **stop and diagnose the failure** instead of repeatedly applying the same command.

The primary objective is a **controlled K3s-vs-raw-Kubernetes experiment**, not simply obtaining a `kubectl get nodes` result.

---

# END STATE

The final lab should look conceptually like:

```text
                         HOST
                  Ryzen 5 5600G / 64GB
                           │
              ┌────────────┴────────────┐
              │                         │
       Existing Lab                 K3s Lab
       Raw Kubernetes               Experiment
              │                         │
        ┌─────┴─────┐           ┌───────┴───────┐
        │           │           │               │
    Cluster A   Cluster B   Cluster A       Cluster B
                                  │               │
                              K3s + Cilium    K3s + Cilium
                                  │               │
                              Helm + Argo     Helm + Argo
                                  │               │
                              Workloads       Workloads
                                  │               │
                                  └───────┬───────┘
                                          │
                                  Resource Measurement
                                          │
                             CPU / RAM / Temp / Disk
                                          │
                                          ▼
                               K8s vs K3s Report
```

The existing lab is the **control group**.

The new K3s lab is the **experimental group**.

Keep the two environments isolated so the measurements are meaningful.
