# Kubernetes Engineer Interview Preparation

**80 Real-World Questions & Answers**

Sources: Reddit r/kubernetes, CKAD practice exams, production incident reports, KORE1, DataCamp, Spacelift, LivingDevOps, and candidate-reported interview rounds (2025-2026).

---

## Part 1: Core Concepts & Architecture (1-10)

### Q1: Walk me through what happens when you run `kubectl apply -f deployment.yaml`.

**Answer:**
1. **API Server** receives the request, authenticates, authorizes, and runs admission controllers
2. **etcd** stores the desired state
3. **Deployment Controller** notices the gap between desired and actual state, creates a ReplicaSet
4. **ReplicaSet Controller** creates Pod objects
5. **Scheduler** assigns pods to nodes based on resource requests, taints, tolerations, and affinity
6. **Kubelet** on the target node pulls the image and starts the container via the runtime (containerd/CRI-O)
7. **CNI plugin** (Cilium/Calico) assigns pod IP and configures networking

**Where it can stall**: admission webhooks blocking, insufficient resources, image pull failures, taints without tolerations.

---

### Q2: What is etcd, and what happens if it goes down?

**Answer:**
etcd is the distributed key-value store that holds all cluster state (pods, services, secrets, configs). If etcd goes down:
- **API server becomes unreachable** — no reads or writes possible
- **Existing pods keep running** — kubelet and controllers operate independently
- **No new deployments, scaling, or changes** — cluster is effectively frozen
- **In HA setups** (3 or 5 nodes), losing a minority node is tolerable; losing a majority causes split-brain

**Production tip**: Always back up etcd with `etcdctl snapshot save` and test restores regularly.

---

### Q3: What is the difference between a Pod and a Deployment?

**Answer:**
| Aspect | Pod | Deployment |
|--------|-----|------------|
| **What it is** | Smallest deployable unit (1+ containers) | Controller that manages ReplicaSets |
| **Self-healing** | No — if pod dies, it's gone | Yes — recreates pods automatically |
| **Scaling** | Manual | `kubectl scale` or HPA |
| **Rolling updates** | Not supported | Built-in |
| **Use case** | Debug pods, batch jobs | Production workloads |

---

### Q4: Explain the difference between resource Requests and Limits. What happens when a container exceeds its memory limit?

**Answer:**
- **Requests**: Used for **scheduling** — the scheduler uses this to decide which node to place the pod on
- **Limits**: Used for **runtime enforcement** — the hard ceiling

When a container exceeds its memory limit:
- The Linux kernel OOM killer terminates the container
- Kubernetes marks it as `OOMKilled`
- If under a Deployment, it gets restarted
- This is NOT the same as an application crash — it's an external kill

**CPU throttling differs**: Exceeding CPU limits doesn't kill the container — it throttles it (slows it down).

**Best practice**: Set requests = limits for guaranteed QoS class.

---

### Q5: What are the different Kubernetes Service types?

**Answer:**
| Type | Access | Use Case |
|------|--------|----------|
| **ClusterIP** | Internal only (default) | Microservice-to-microservice |
| **NodePort** | External via `<NodeIP>:<Port>` | Development, simple exposure |
| **LoadBalancer** | Cloud provider LB | Production external access |
| **ExternalName** | DNS CNAME alias | Reference external services |

**Headless Service** (clusterIP: None): Returns pod IPs directly — used for StatefulSets, databases.

---

### Q6: What is a CNI plugin and why does it matter?

**Answer:**
CNI (Container Network Interface) is responsible for:
- Assigning IP addresses to pods
- Configuring pod-to-pod networking
- Implementing NetworkPolicies

**Common CNIs**: Cilium (eBPF-based), Calico, Flannel, Weave

**Critical point**: NetworkPolicies only work if the CNI enforces them. Flannel does NOT enforce NetworkPolicies — it just provides networking. Cilium and Calico do enforce them.

---

### Q7: What is the difference between a liveness probe, readiness probe, and startup probe?

**Answer:**
| Probe | Purpose | Failure Action |
|-------|---------|----------------|
| **Liveness** | Is the app alive? | Container restarted |
| **Readiness** | Is the app ready for traffic? | Removed from Service endpoints |
| **Startup** | Has the app finished starting? | Disables liveness/readiness until ready |

**Common mistake**: Setting an aggressive liveness probe on a slow-starting app causes a restart loop — the app never passes the probe, gets killed, restarts, and the cycle repeats. Use startup probes for slow-starting apps.

---

### Q8: What replaced PodSecurityPolicy (PSP)?

**Answer:**
PSP was deprecated in v1.21 and removed in v1.25. It's replaced by:
- **Pod Security Admission** (built-in): Uses labels on namespaces to enforce `privileged`, `baseline`, or `restricted` profiles
- **OPA Gatekeeper** or **Kyverno**: For more granular, custom policies

Example:
```bash
kubectl label namespace production pod-security.kubernetes.io/enforce=restricted
```

---

### Q9: What is the difference between `kubectl apply` and `kubectl create`?

**Answer:**
- **`kubectl create`**: Creates a new resource. Fails if it already exists (unless `--save-config` is used)
- **`kubectl apply`**: Creates or updates. If the resource exists, it patches it with the new spec. Uses a last-applied-configuration annotation for three-way merge

**Best practice**: Use `apply` for declarative management. Use `create` for one-off imperative creation.

---

### Q10: What are Taints and Tolerations?

**Answer:**
- **Taint**: Applied to a node — repels pods that don't tolerate the taint
- **Toleration**: Applied to a pod — allows it to be scheduled on tainted nodes

```bash
# Taint a node
kubectl taint nodes node1 dedicated=gpu:NoSchedule

# Pod toleration
tolerations:
- key: "dedicated"
  operator: "Equal"
  value: "gpu"
  effect: "NoSchedule"
```

**Use cases**: Dedicated nodes for specific workloads, keeping system pods on control plane nodes.

---

## Part 2: Pods & Controllers (11-20)

### Q11: What is the difference between a Deployment and a StatefulSet?

**Answer:**
| Aspect | Deployment | StatefulSet |
|--------|-----------|-------------|
| **Pod names** | Random (`web-7d8b4`) | Ordered (`web-0`, `web-1`) |
| **Scaling** | Any order | Sequential (one at a time) |
| **Storage** | Shared or none | Per-pod PVC, sticky |
| **Network** | Load balanced | Stable DNS names |
| **Use case** | Stateless apps | Databases, queues, caches |

---

### Q12: What is a DaemonSet?

**Answer:**
A DaemonSet ensures exactly one pod runs on every node (or a subset). Used for:
- Log collectors (Fluentd, Filebeat)
- Monitoring agents (Prometheus Node Exporter, Datadog)
- CNI plugins (Cilium)
- Storage daemons

```bash
kubectl get daemonset -n kube-system
```

**Note**: By default, DaemonSets respect NoSchedule taints. Use `tolerations` to run on control plane nodes.

---

### Q13: How do you perform a rolling update and rollback?

**Answer:**
```bash
# Rolling update (default strategy)
kubectl set image deployment/web nginx=nginx:1.21

# Watch progress
kubectl rollout status deployment/web

# Rollback to previous version
kubectl rollout undo deployment/web

# Rollback to specific revision
kubectl rollout undo deployment/web --to-revision=3

# View history
kubectl rollout history deployment/web
```

**Key settings**:
- `maxUnavailable`: How many pods can be down during update
- `maxSurge`: How many extra pods can be created

---

### Q14: What is a Job and a CronJob?

**Answer:**
**Job**: Creates pods that run to completion (batch processing)
```bash
kubectl create job my-job --image=alpine -- date
```

**CronJob**: Runs Jobs on a schedule
```bash
kubectl create cronjob my-cron --image=alpine --schedule="*/5 * * * *" -- date
```

**Key parameters**:
- `backoffLimit`: How many retries before marking as failed
- `ttlSecondsAfterFinished`: Auto-cleanup after completion
- `concurrencyPolicy`: Allow, Forbid, or Replace

---

### Q15: What happens when you delete a pod from a 3-replica StatefulSet?

**Answer:**
The StatefulSet controller recreates the pod with the **same name** (e.g., `web-0`). It does NOT rename other pods to fill the gap. The pod identity is preserved, and it reattaches to its PersistentVolume if configured.

---

### Q16: What is a PodDisruptionBudget (PDB)?

**Answer:**
A PDB limits voluntary disruptions (node drain, cluster upgrade) to ensure availability.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
spec:
  minAvailable: 2  # or maxUnavailable: 1
  selector:
    matchLabels:
      app: web
```

**Critical for zero-downtime upgrades**: Without a PDB, `kubectl drain` can evict all pods simultaneously.

---

### Q17: What is the difference between a Job with `restartPolicy: Never` and `restartPolicy: OnFailure`?

**Answer:**
- **`Never`**: Failed pods are replaced with new pods (different pod, same job)
- **`OnFailure`**: The same pod restarts (container only, pod stays on the same node)

**Use `Never`** when you want the job to potentially land on a different node. Use `OnFailure` when the failure is likely transient and the node is fine.

---

### Q18: How does Kubernetes handle pod eviction during node pressure?

**Answer:**
1. Kubelet detects pressure (memory, disk, PID)
2. Kubelet **evicts pods** starting with lowest priority, then highest resource usage
3. Evicted pods get `Failed` status with reason `Evicted`
4. Pods with **Guaranteed QoS** (requests = limits) are evicted last
5. DaemonSet pods are NOT evicted

**Node conditions**: `MemoryPressure`, `DiskPressure`, `PIDPressure`, `Ready`

---

### Q19: What is the purpose of init containers?

**Answer:**
Init containers run **before** the main container starts and must complete successfully. Used for:
- Waiting for dependencies (database, config)
- Running setup scripts
- Cloning git repos
- Checking external service availability

```yaml
initContainers:
- name: wait-for-db
  image: busybox
  command: ['sh', '-c', 'until nslookup mydb; do sleep 2; done']
```

---

### Q20: Can two containers in the same Pod bind to the same port?

**Answer:**
**No** — containers in the same Pod share the network namespace (same IP, same port space). Two containers cannot bind to the same port on the same protocol.

**Workaround**: One container listens on a different port, or use `hostNetwork: true` (not recommended).

---

## Part 3: Services & Networking (21-30)

### Q21: How does Kubernetes DNS work?

**Answer:**
CoreDNS provides DNS resolution within the cluster:
- **Service DNS**: `<service-name>.<namespace>.svc.cluster.local`
- **Pod DNS**: `<pod-ip-dashed>.<namespace>.pod.cluster.local`
- **Headless Service**: Returns individual pod IPs

```bash
# Test DNS from inside a pod
kubectl run test --rm -it --image=busybox -- nslookup kubernetes.default
```

**Troubleshooting**: If DNS fails, check CoreDNS pods in `kube-system` and the pod's `/etc/resolv.conf`.

---

### Q22: What is a NetworkPolicy and how do you create a default-deny-all?

**Answer:**
A NetworkPolicy controls pod-to-pod traffic. Default deny all:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**Important**: Requires a CNI that enforces NetworkPolicy (Cilium, Calico). Flannel does NOT enforce them.

---

### Q23: A Service has no endpoints. How do you debug?

**Answer:**
```bash
# Check endpoints
kubectl get svc my-service -o yaml | grep -A5 endpoints

# Check pod labels match service selector
kubectl get pods --show-labels
kubectl get svc my-service -o jsonpath='{.spec.selector}'

# Check pod readiness (only ready pods get endpoints)
kubectl get pods -l app=myapp

# Check readiness probe
kubectl describe pod <pod-name> | grep -A5 readinessProbe
```

**Common causes**: Label mismatch, pods not ready, wrong port, NetworkPolicy blocking.

---

### Q24: What is the difference between `port`, `targetPort`, and `nodePort`?

**Answer:**
- **port**: The port the Service listens on (inside the cluster)
- **targetPort**: The port the container is listening on (where traffic is forwarded)
- **nodePort**: The port exposed on every node (for NodePort/LoadBalancer services)

```yaml
ports:
- port: 80          # Service listens on 80
  targetPort: 8080  # Container listens on 8080
  nodePort: 30080   # Exposed on nodes at 30080
```

---

### Q25: How do you implement zero-downtime deployments?

**Answer:**
Combine these components:
1. **Readiness probe** — prevents traffic to unready pods
2. **preStop hook** — drains connections before termination
3. **PodDisruptionBudget** — ensures minimum availability
4. **Rolling update** with appropriate `maxUnavailable`/`maxSurge`

```yaml
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 15"]
terminationGracePeriodSeconds: 30
```

---

### Q26: What is an Ingress and when would you use it over a NodePort?

**Answer:**
An Ingress provides HTTP/HTTPS routing at layer 7 (vs layer 4 for NodePort):
- **Path-based routing** (`/api` → service-a, `/web` → service-b)
- **Host-based routing** (`api.example.com` → service-a)
- **TLS termination** (SSL certificates)
- **Load balancing** (round-robin, sticky sessions)

Requires an Ingress Controller (NGINX, Traefik, Cilium).

---

### Q27: How do you debug intermittent connectivity between services?

**Answer:**
```bash
# Test from inside cluster
kubectl run test --rm -it --image=busybox -- wget -qO- --timeout=5 http://my-service

# Check DNS resolution
nslookup my-service.default.svc.cluster.local

# Check for packet drops
kubectl exec <pod> -- tcpdump -i eth0 -nn port 80

# Check NetworkPolicy
kubectl get networkpolicies -o yaml

# Check Cilium connectivity
cilium status
cilium connectivity test
```

---

### Q28: What is a Headless Service?

**Answer:**
A Headless Service (`clusterIP: None`) returns pod IPs directly instead of a single VIP. Used for:
- StatefulSets (stable DNS per pod)
- Databases (clients connect to specific pods)
- Custom load balancing

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-db
spec:
  clusterIP: None
  selector:
    app: my-db
  ports:
  - port: 5432
```

Pods get DNS: `my-db-0.my-db.default.svc.cluster.local`

---

### Q29: What happens when a node goes NotReady?

**Answer:**
1. After `pod-eviction-timeout` (default 5 min), pods on the node are evicted
2. Deployments/StatefulSets recreate pods on other nodes
3. DaemonSet pods stay (node might recover)
4. PersistentVolume data is retained (not deleted with the pod)

**Immediate actions**:
```bash
# Check node conditions
kubectl describe node <node-name> | grep -A5 Conditions

# Force drain if needed
kubectl drain <node> --force --ignore-daemonsets
```

---

### Q30: What is Cilium and why is it special?

**Answer:**
Cilium is a CNI plugin based on **eBPF** (extended Berkeley Packet Filter):
- **Kernel-level networking** — no kube-proxy needed
- **NetworkPolicy enforcement** at the kernel level
- **Hubble** — built-in observability (flow logs, metrics)
- **Service mesh** capabilities (mTLS without sidecars)
- **Performance** — bypasses iptables for better throughput

**Trade-off**: More complex to configure than Calico/Flannel, but more powerful.

---

## Part 4: Storage & Persistent Volumes (31-38)

### Q31: Explain the PV/PVC/StorageClass chain.

**Answer:**
```
StorageClass → defines how to provision storage (CSI driver, parameters)
    ↓
PersistentVolume (PV) → actual storage resource (NFS, EBS, local)
    ↓
PersistentVolumeClaim (PVC) → request for storage (size, access mode)
```

**Flow**: PVC → StorageClass → dynamic provisioner creates PV → PVC bound to PV

**Access modes**: ReadWriteOnce (RWO), ReadOnlyMany (ROX), ReadWriteMany (RWX)

---

### Q32: A PVC is stuck in Pending. How do you fix it?

**Answer:**
```bash
# Check PVC status
kubectl describe pvc my-pvc

# Common causes:
# 1. No matching StorageClass
kubectl get sc

# 2. StorageClass provisioner not running
kubectl get pods -n kube-system | grep provisioner

# 3. No available PVs (manual provisioning)
kubectl get pv

# 4. Wrong access mode for the provisioner
```

---

### Q33: A StatefulSet pod gets rescheduled to a different node. What happens to its data?

**Answer:**
Depends on the storage backend:
- **local-path-provisioner**: Data is lost (stored on original node's disk)
- **NFS/CephFS**: Data persists (network storage)
- **Cloud EBS/GCE PD**: Volume may not attach to new node without proper configuration
- **Longhorn/Rook-Ceph**: Data replicates across nodes, survives rescheduling

**For databases**: Always use network-attached or replicated storage.

---

### Q34: What is the difference between `ReadWriteOnce`, `ReadOnlyMany`, and `ReadWriteMany`?

**Answer:**
| Mode | Description | Use Case |
|------|-------------|----------|
| **RWO** | Single node read-write | Databases, single-pod apps |
| **ROX** | Multiple nodes read-only | Shared configs, static content |
| **RWX** | Multiple nodes read-write | Shared filesystems, CMS |

**Not all storage supports all modes.** Check your StorageClass/CSI driver.

---

### Q35: How do you resize a PVC?

**Answer:**
Kubernetes 1.11+ supports volume expansion:
```bash
# Check if StorageClass allows expansion
kubectl get sc local-path -o yaml | grep allowVolumeExpansion

# Edit PVC to increase size
kubectl patch pvc my-pvc -p '{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}'

# Verify
kubectl get pvc my-pvc
```

**Note**: You can only increase, not decrease. Some storage backends require the pod to be restarted.

---

### Q36: What is dynamic provisioning?

**Answer:**
Dynamic provisioning automatically creates PVs when a PVC is requested, without manual intervention. The StorageClass specifies which provisioner to use.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
volumeBindingMode: WaitForFirstConsumer
```

**Without dynamic provisioning**: An admin must manually create PVs before PVCs can be bound.

---

### Q37: What is `volumeBindingMode: WaitForFirstConsumer`?

**Answer:**
This delays PV creation until a pod that uses the PVC is scheduled. Why it matters:
- Ensures the storage is in the same zone/region as the pod
- Prevents cross-zone latency issues
- Required for topology-aware storage (cloud environments)

**Without it**: PV is created immediately, potentially in a different zone than the pod.

---

### Q38: How do you back up PVC data?

**Answer:**
```bash
# Method 1: Clone PVC (if StorageClass supports it)
kubectl get pvc my-pvc -o yaml | sed 's/my-pvc/my-pvc-backup/' | kubectl apply -f -

# Method 2: Use Velero (backup entire volumes)
velero backup create my-backup --include-resources persistentvolumeclaims

# Method 3: Manual backup from pod
kubectl exec -it my-pod -- tar czf /tmp/backup.tar.gz /data
kubectl cp my-pod:/tmp/backup.tar.gz ./backup.tar.gz
```

---

## Part 5: Security & RBAC (39-48)

### Q39: Are Kubernetes Secrets encrypted by default?

**Answer:**
**No.** Secrets are base64-encoded, not encrypted. Anyone with API access or etcd access can decode them.

**To enable encryption at rest**:
```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources: ["secrets"]
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: <base64-encoded-key>
    - identity: {}  # fallback
```

**Best practice**: Use external vaults (HashiCorp Vault, AWS Secrets Manager), enable encryption at rest, tighten RBAC.

---

### Q40: What is RBAC and why is it important?

**Answer:**
RBAC (Role-Based Access Control) restricts who can do what in the cluster:
- **Role**: Permissions within a namespace
- **ClusterRole**: Permissions across all namespaces
- **RoleBinding**: Grants Role to a user/group/serviceaccount
- **ClusterRoleBinding**: Grants ClusterRole cluster-wide

```bash
# Check what you can do
kubectl auth can-i --list
kubectl auth can-i create pods -n production
```

**Principle of least privilege**: Give only the permissions needed. Don't use cluster-admin for application workloads.

---

### Q41: What is a ServiceAccount and how does it differ from a User?

**Answer:**
| Aspect | ServiceAccount | User |
|--------|---------------|------|
| **Purpose** | Pod identity | Human identity |
| **Scope** | Namespace | Cluster-wide |
| **Token** | Auto-mounted in pod | Manual/kubeconfig |
| **RBAC** | Can be bound to Roles | Can be bound to Roles |

```yaml
spec:
  serviceAccountName: my-app  # pod uses this identity
```

**Security**: Delete unused ServiceAccounts. Don't use the `default` SA for workloads.

---

### Q42: How do you enforce that all images come from a trusted registry?

**Answer:**
Use admission control (Pod Security Admission + OPA/Kyverno):
```yaml
# Kyverno policy
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-trusted-registries
spec:
  validationFailureAction: Enforce
  rules:
  - name: validate-registries
    match:
      any:
      - resources:
          kinds: ["Pod"]
    validate:
      message: "Images must come from internal registry"
      pattern:
        spec:
          containers:
          - image: "registry.internal.com/*"
```

---

### Q43: What is a mutating admission webhook?

**Answer:**
A webhook that intercepts API requests and **modifies** the object before it's stored. Used for:
- Injecting sidecars (Istio)
- Adding default labels/annotations
- Modifying resource requests
- Setting security contexts

**Flow**: API Server → Admission Webhooks → Mutating (modify) → Validating (verify) → etcd

---

### Q44: How do you implement multi-tenancy on a shared cluster?

**Answer:**
1. **Namespace isolation**: Each tenant gets their own namespace
2. **RBAC**: Role per namespace, no ClusterRoles for tenants
3. **ResourceQuota**: Limit CPU/memory/pods per namespace
4. **NetworkPolicy**: Isolate tenant namespaces
5. **Pod Security Admission**: Restrict privileged pods
6. **LimitRange**: Set default resource limits

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-a-quota
  namespace: tenant-a
spec:
  hard:
    pods: "20"
    requests.cpu: "4"
    requests.memory: 8Gi
```

---

### Q45: What is the difference between a SecurityContext at pod level vs container level?

**Answer:**
```yaml
spec:
  securityContext:  # Pod-level — affects all containers
    runAsNonRoot: true
    fsGroup: 1000
  containers:
  - name: app
    securityContext:  # Container-level — overrides pod-level
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
```

**Pod-level**: Shared settings (user, group, SELinux)
**Container-level**: Per-container settings (privilege escalation, capabilities)

---

### Q46: How do you rotate Kubernetes Secrets?

**Answer:**
```bash
# Create new secret
kubectl create secret generic my-secret --from-literal=password=newpass -n my-ns

# Update deployment to reference new secret
kubectl set env deployment/my-app SECRET_NAME=my-secret-v2

# Or patch the volume
kubectl patch deployment my-app -p '{"spec":{"template":{"spec":{"volumes":[{"name":"secret","secret":{"secretName":"my-secret-v2"}}]}}}}'

# Delete old secret
kubectl delete secret my-secret-old -n my-ns
```

**For etcd encryption**: Rotate the encryption key in the EncryptionConfiguration.

---

### Q47: What is the `default` ServiceAccount and why should you avoid using it?

**Answer:**
Every namespace has a `default` ServiceAccount. If you don't specify a ServiceAccount in a pod spec, it uses `default`.

**Problems**:
- It may have more permissions than needed (depends on cluster config)
- It's the same for all pods in the namespace (no isolation)
- Tokens are auto-mounted (potential token theft)

**Best practice**: Create a dedicated ServiceAccount per application with minimal RBAC.

---

### Q48: How do you audit Kubernetes API requests?

**Answer:**
Enable audit logging in API server configuration:
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]
- level: Metadata
  resources:
  - group: ""
    resources: ["pods", "services"]
```

**Audit levels**: None, Metadata, Request, RequestResponse

**Store audit logs**: Ship to Elasticsearch, Loki, or cloud logging services.

---

## Part 6: Troubleshooting & Debugging (49-60)

### Q49: A pod is in CrashLoopBackOff. Walk me through your troubleshooting process.

**Answer:**
```bash
# 1. Check pod status and events
kubectl describe pod <pod-name>

# 2. Check current logs
kubectl logs <pod-name>

# 3. Check previous container logs
kubectl logs <pod-name> --previous

# 4. Check resource limits (OOMKilled?)
kubectl describe pod <pod-name> | grep -A3 "Last State"

# 5. Check ConfigMaps/Secrets
kubectl get configmap,secret -n <namespace>

# 6. Check if dependency is up
kubectl run debug --rm -it --image=busybox -- nslookup mydb
```

**Common causes**: Application error, missing env var, bad config, dependency down, wrong command, OOMKilled.

---

### Q50: A pod is stuck in Pending. How do you diagnose?

**Answer:**
```bash
# Check events
kubectl describe pod <pod-name> | grep -A10 Events

# Common causes:
# 1. Insufficient resources
kubectl top nodes

# 2. Taints without tolerations
kubectl describe nodes | grep -A3 Taints

# 3. Unbound PVC
kubectl get pvc

# 4. Node affinity can't be satisfied
kubectl get pods -o wide

# 5. All nodes are NotReady
kubectl get nodes
```

---

### Q51: A container shows OOMKilled. What do you do?

**Answer:**
```bash
# Check current memory usage
kubectl top pod <pod-name>

# Check memory limit
kubectl describe pod <pod-name> | grep -A3 Limits

# Check if it's a leak or legitimate need
kubectl top pod <pod-name> --containers
```

**Options**:
1. Increase memory limit (if legitimate need)
2. Fix memory leak (if application bug)
3. Profile the application to find the root cause
4. Add memory alerts in monitoring

---

### Q52: DNS resolution fails inside pods. How do you troubleshoot?

**Answer:**
```bash
# Check CoreDNS pods
kubectl -n kube-system get pods -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl -n kube-system logs -l k8s-app=kube-dns

# Check pod's DNS config
kubectl exec <pod> -- cat /etc/resolv.conf

# Test DNS resolution
kubectl exec <pod> -- nslookup kubernetes.default

# Check CoreDNS ConfigMap
kubectl -n kube-system get configmap coredns -o yaml
```

**Common issues**: CoreDNS pod down, wrong DNS policy, network policy blocking DNS port 53.

---

### Q53: An Ingress returns 404 or 502. How do you debug?

**Answer:**
```bash
# Check Ingress resource
kubectl get ingress <name> -o yaml

# Check Ingress Controller logs
kubectl -n ingress-nginx logs -l app.kubernetes.io/name=ingress-nginx

# Verify backend service exists and has endpoints
kubectl get svc <backend-svc>
kubectl get endpoints <backend-svc>

# Check service port matches Ingress targetPort
kubectl describe ingress <name>

# Test backend directly
kubectl run test --rm -it --image=busybox -- wget -qO- http://<backend-svc>:<port>
```

---

### Q54: A node shows NotReady. How do you fix it?

**Answer:**
```bash
# SSH to the node
ssh debian@<node-ip>

# Check kubelet status
sudo systemctl status k3s-agent

# Check kubelet logs
sudo journalctl -u k3s-agent --since "10 minutes ago"

# Check system resources
free -h
df -h

# Check container runtime
sudo crictl ps

# Restart kubelet
sudo systemctl restart k3s-agent
```

**If node is unrecoverable**:
```bash
kubectl drain <node> --force --ignore-daemonsets --delete-emptydir-data
kubectl delete node <node>
```

---

### Q55: How do you debug a pod that runs but gets no traffic?

**Answer:**
```bash
# Check if pod is ready
kubectl get pod <pod-name>

# Check Service endpoints
kubectl get endpoints <service-name>

# Verify Service selector matches pod labels
kubectl get svc <service-name> -o jsonpath='{.spec.selector}'
kubectl get pods --show-labels

# Check NetworkPolicy
kubectl get networkpolicies -o yaml

# Test direct pod access
kubectl run test --rm -it --image=busybox -- wget -qO- http://<pod-ip>:<port>

# Check Ingress (if applicable)
kubectl describe ingress <name>
```

---

### Q56: A deployment rollout is stuck. How do you investigate?

**Answer:**
```bash
# Check rollout status
kubectl rollout status deployment/<name>

# Check new replica set
kubectl get rs -l app=<name>

# Check events
kubectl get events --sort-by='.lastTimestamp' | head -20

# Check new pod status
kubectl get pods -l app=<name>

# Check if old pods are terminating
kubectl describe rs <new-rs-name>
```

**Common causes**: New pods fail readiness, image pull issues, resource constraints, dependency failures.

---

### Q57: How do you troubleshoot RBAC permission issues?

**Answer:**
```bash
# Test if you can do something
kubectl auth can-i list pods -n <namespace>
kubectl auth can-i create deployments -n <namespace>

# Test as specific user
kubectl auth can-i list pods --as=system:serviceaccount:<ns>:<sa>

# List all permissions for a user
kubectl auth can-i --list --as=<user>

# Check RoleBindings
kubectl get rolebindings -n <namespace> -o yaml

# Check ClusterRoleBindings
kubectl get clusterrolebindings -o yaml | grep -A5 <user-or-sa>
```

---

### Q58: A PVC is stuck in Pending and pods can't start. How do you fix it?

**Answer:**
```bash
# Check PVC status
kubectl describe pvc <pvc-name>

# Check StorageClass
kubectl get sc

# Check provisioner pods
kubectl get pods -A | grep -i provisioner

# Check for available PVs
kubectl get pv

# If using local storage, check node capacity
df -h
```

---

### Q59: How do you debug high latency in a Kubernetes application?

**Answer:**
```bash
# Check CPU throttling (limits too low)
kubectl top pod <pod-name> --containers

# Check resource requests vs actual usage
kubectl top pod <pod-name>

# Check node load
kubectl top nodes

# Check network latency between pods
kubectl run test --rm -it --image=busybox -- ping <service-name>

# Check for pod restarts (process instability)
kubectl get pods -l app=<name>

# Check Prometheus/Grafana for trends
```

---

### Q60: How do you troubleshoot a service that can't connect to an external database?

**Answer:**
```bash
# Test from inside the cluster
kubectl run test --rm -it --image=busybox -- nslookup <db-host>

# Test connectivity
kubectl run test --rm -it --image=busybox -- nc -zv <db-host> 5432

# Check if egress is blocked by NetworkPolicy
kubectl get networkpolicies -o yaml | grep -A5 egress

# Check if the database IP is routable from the cluster
# (especially in hybrid/cloud setups)

# Verify credentials
kubectl get secret <secret-name> -o jsonpath='{.data.password}' | base64 -d
```

---

## Part 7: Production Scenarios (61-72)

### Q61: Your application is slow but not down. How do you investigate?

**Answer:**
**Systematic approach**:
1. Check **metrics** — CPU throttling? Memory pressure? Network errors?
2. Check **logs** — slow queries? timeouts? retries?
3. Check **dependencies** — database latency? downstream services?
4. Check **pod placement** — noisy neighbor? same node as resource-heavy pod?
5. Check **resource limits** — are limits causing throttling?
6. Check **network** — DNS latency? packet drops?

**Common root causes**: CPU throttling (limits too low), database connection pool exhaustion, GC pauses, network latency.

---

### Q62: A rolling update caused downtime even though it was configured. What went wrong?

**Answer:**
**Common causes**:
1. **Readiness probe not configured** — new pods receive traffic before app is ready
2. **No preStop hook** — old pods terminated before draining connections
3. **maxUnavailable too high** — too many pods down simultaneously
4. **No PodDisruptionBudget** — PDB not protecting availability
5. **Startup probe missing** — liveness probe kills pod before app starts

**Fix**:
```yaml
strategy:
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
  type: RollingUpdate
```

---

### Q63: Cluster resources are exhausted and new pods are Pending. What do you do?

**Answer:**
**Immediate**:
1. Identify resource-heavy pods: `kubectl top pods --sort-by=memory`
2. Scale down non-critical workloads
3. Check if Cluster Autoscaler is enabled and functioning

**Long-term**:
1. Set resource requests/limits on all pods
2. Implement HPA for auto-scaling
3. Enable Cluster Autoscaler
4. Add resource quotas per namespace
5. Review and right-size workloads

---

### Q64: How do you handle a production incident where multiple services are failing?

**Answer:**
**Incident response**:
1. **Triage**: What's affected? How severe?
2. **Stabilize**: Roll back recent changes, scale up healthy services
3. **Isolate**: Can you identify the root cause service?
4. **Fix**: Apply the fix, validate recovery
5. **Prevent**: Add monitoring, alerts, runbooks

**Kubernetes-specific**:
```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A --field-selector=status.phase!=Running

# Check recent events
kubectl get events --sort-by='.lastTimestamp' | head -30

# Check resource pressure
kubectl top nodes
kubectl describe nodes | grep -A5 Conditions
```

---

### Q65: How do you safely drain a node for maintenance?

**Answer:**
```bash
# 1. Cordon the node (prevent new pods)
kubectl cordon <node>

# 2. Drain (evict pods gracefully)
kubectl drain <node> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=60 \
  --timeout=300s

# 3. Perform maintenance (OS update, hardware swap, etc.)

# 4. Uncordon (allow scheduling again)
kubectl uncordon <node>
```

**Critical**: Ensure PDBs are configured so critical services maintain availability.

---

### Q66: etcd backup failed. How do you recover?

**Answer:**
**If etcd is still running but backup failed**:
```bash
# Check etcd health
etcdctl endpoint health --cacert=... --cert=... --key=...

# Try backup again
etcdctl snapshot save /backup/etcd-$(date +%Y%m%d).db

# Check disk space
df -h /var/lib/rancher/k3s/server/db/
```

**If etcd is corrupted**:
```bash
# Restore from last known good backup
etcdctl snapshot restore /backup/etcd-20260904.db \
  --data-dir=/var/lib/rancher/k3s/server/db/etcd-restore

# Restart k3s
sudo systemctl restart k3s
```

**Prevention**: Automate backups with CronJob, monitor backup status, test restores.

---

### Q67: How do you implement canary deployments in Kubernetes?

**Answer:**
**Method 1: Replica-based**
```yaml
# Stable (90% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-stable
spec:
  replicas: 9

# Canary (10% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-canary
spec:
  replicas: 1
```

**Method 2: Using Argo Rollouts or Flagger** (more sophisticated):
- Traffic splitting based on weight
- Automated rollback on metrics degradation
- Progressive delivery

---

### Q68: A secret was accidentally deleted. How do you recover?

**Answer:**
**If you have etcd backup**:
```bash
# Restore specific secret from backup
etcdctl snapshot restore /backup/etcd.db --data-dir=/tmp/etcd-restore
# Then extract the secret from the restored data
```

**If no backup**:
- Secrets are NOT automatically recreated
- You must recreate them manually or from source control
- Any pods using the secret may need restart

**Prevention**:
- Store secrets in Git (encrypted with SealedSecrets or SOPS)
- Use external vault (HashiCorp Vault, AWS Secrets Manager)
- Implement RBAC to prevent accidental deletion
- Enable etcd encryption at rest

---

### Q69: How do you handle certificate expiration in a Kubernetes cluster?

**Answer:**
```bash
# Check certificate expiration
kubeadm certs check-expiration  # kubeadm clusters
openssl x509 -in /var/lib/rancher/k3s/server/tls/server.crt -noout -dates  # k3s

# Renew certificates
kubeadm certs renew all  # kubeadm
# k3s auto-renews, but may need restart

# Check API server certificate
openssl s_client -connect <api-server>:6443 2>/dev/null | openssl x509 -noout -dates
```

**Prevention**: Monitor certificate expiration, use cert-manager for automatic renewal.

---

### Q70: How do you implement logging in Kubernetes?

**Answer:**
**Options**:
1. **kubectl logs** — quick debugging, but temporary
2. **DaemonSet log collector** — Fluentd/Filebeat ships logs to central store
3. **Sidecar container** — dedicated log shipper per pod
4. **Application-level logging** — app writes to stdout/stderr

**Stack**:
- **Collection**: Fluentd, Fluent Bit, Vector
- **Storage**: Elasticsearch, Loki, CloudWatch
- **Visualization**: Grafana, Kibana

```bash
# View logs from all pods with label
kubectl logs -l app=myapp --all-containers

# Follow logs in real-time
kubectl logs -f <pod-name>

# View previous container logs (after crash)
kubectl logs <pod-name> --previous
```

---

### Q71: How do you implement monitoring in Kubernetes?

**Answer:**
**Components**:
1. **Metrics Server** — basic CPU/memory metrics (required for HPA)
2. **Prometheus** — time-series metrics collection
3. **Grafana** — visualization dashboards
4. **AlertManager** — alert routing and notification

**Deployment**:
```bash
# Deploy kube-prometheus-stack (includes all components)
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

**What to monitor**:
- Node health (CPU, memory, disk, network)
- Pod health (restarts, OOMKilled, CrashLoopBackOff)
- API server latency
- etcd performance
- Custom application metrics

---

### Q72: How do you handle a cascading failure in production?

**Answer:**
**Example**: HPA scales up → nodes overloaded → pods evicted → more scaling → more overload

**Immediate actions**:
1. **Stop the cascade**: Scale down HPA or set max replicas
2. **Stabilize**: Manually set desired replica count
3. **Identify root cause**: Memory leak? Traffic spike? Misconfiguration?
4. **Fix**: Deploy fix, adjust limits, add capacity

**Prevention**:
- Set HPA `maxReplicas` to reasonable ceiling
- Configure Cluster Autoscaler with proper limits
- Implement circuit breakers in applications
- Add rate limiting at ingress
- Monitor and alert on resource exhaustion

---

## Part 8: Advanced Topics (73-80)

### Q73: What is the Horizontal Pod Autoscaler (HPA) and how does it work?

**Answer:**
HPA automatically scales pod replicas based on metrics:
- **CPU**: Scales when CPU utilization exceeds target
- **Memory**: Scales when memory usage exceeds target
- **Custom metrics**: Scales on custom metrics (queue depth, requests/sec)
- **External metrics**: Scales on external metrics (SQS queue length, Prometheus queries)

```bash
kubectl autoscale deployment web --cpu-percent=50 --min=2 --max=10
```

**Key**: HPA requires resource requests to be set — it calculates utilization as a percentage of requests.

---

### Q74: What is the Cluster Autoscaler and how does it differ from HPA?

**Answer:**
| Aspect | HPA | Cluster Autoscaler |
|--------|-----|---------------------|
| **What it scales** | Pod replicas | Cluster nodes |
| **Trigger** | CPU/memory/custom metrics | Pending pods or underutilized nodes |
| **Level** | Application | Infrastructure |

**How Cluster Autoscaler works**:
1. Pods pending due to insufficient resources → adds nodes
2. Nodes underutilized for 10min → removes nodes (with PDB respect)

**HPA + Cluster Autoscaler interaction**: HPA scales pods, Cluster Autoscaler adds nodes when pods can't be scheduled.

---

### Q75: What is KEDA and when would you use it?

**Answer:**
KEDA (Kubernetes Event-Driven Autoscaling) scales based on external events:
- **Kafka**: Scale on consumer lag
- **AWS SQS**: Scale on queue depth
- **Prometheus**: Scale on any metric
- **Cron**: Scale on schedule

**Difference from HPA**: KEDA can scale to **zero** (HPA can't). KEDA works with external event sources that HPA doesn't understand.

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kafka-consumer
spec:
  scaleTargetRef:
    name: my-consumer
  minReplicaCount: 0
  maxReplicaCount: 100
  triggers:
  - type: kafka
    metadata:
      bootstrapServers: my-kafka:9092
      consumerGroup: my-group
      topic: my-topic
      lagThreshold: "50"
```

---

### Q76: What is an Operator and how does it extend Kubernetes?

**Answer:**
An Operator is a custom controller + CRD that manages complex applications:
- **Custom Resource Definition (CRD)**: Defines new resource types
- **Controller**: Watches for changes and reconciles desired state

**Examples**:
- **Prometheus Operator**: Manages Prometheus, AlertManager, ServiceMonitors
- **Cert-Manager**: Manages TLS certificates
- **PostgreSQL Operator**: Manages database clusters

**When to use**: When your application needs domain-specific knowledge (backup, scaling, upgrades) that generic controllers don't provide.

---

### Q77: How do you design a CI/CD pipeline for Kubernetes?

**Answer:**
**GitOps flow**:
1. Developer pushes code to Git
2. CI builds image, pushes to registry
3. CD updates Git repo with new image tag
4. ArgoCD/Flux detects change, syncs to cluster

**Components**:
- **CI**: GitHub Actions, GitLab CI, Jenkins
- **CD**: ArgoCD, Flux
- **Registry**: Docker Hub, ECR, GHCR
- **Policy**: OPA Gatekeeper, Kyverno (validate images)
- **Progressive delivery**: Argo Rollouts, Flagger

**Best practices**:
- Immutable images (no `latest` tag)
- Signed images (Cosign)
- Scanned images (Trivy)
- Helm charts for templating
- Kustomize for overlays

---

### Q78: How do you optimize Kubernetes for cost efficiency?

**Answer:**
1. **Right-size requests/limits** — use VPA recommendations
2. **Use Spot/Preemptible nodes** — 60-90% cheaper for non-critical workloads
3. **Implement Cluster Autoscaler** — remove underutilized nodes
4. **Use HPA** — scale down during low traffic
5. **Delete unused resources** — PVCs, Services, ConfigMaps
6. **Use cost monitoring** — Kubecost, OpenCost
7. **Consolidate workloads** — bin-packing on fewer nodes

```bash
# Find idle resources
kubectl top nodes
kubectl top pods --sort-by=cpu

# Check for unused PVCs
kubectl get pvc -A | grep Bound
```

---

### Q79: How do you implement disaster recovery in Kubernetes?

**Answer:**
**Components to back up**:
1. **etcd** — cluster state (most critical)
2. **PersistentVolumes** — application data
3. **GitOps repo** — desired state (already in Git)
4. **Secrets** — encrypted backups

**Tools**:
- **Velero** — backs up Kubernetes resources + PV snapshots
- **etcdctl** — etcd snapshots
- **Restic/Borg** — file-level backups

**Recovery plan**:
```bash
# 1. Backup etcd
etcdctl snapshot save /backup/etcd.db

# 2. Backup PVs (Velero)
velero backup create daily-backup --snapshot-volumes

# 3. Restore to new cluster
velero restore create --from-backup daily-backup
```

**RPO/RTO targets**: Define Recovery Point Objective (how much data loss is acceptable) and Recovery Time Objective (how fast you need to recover).

---

### Q80: A critical production pod keeps getting evicted. How do you prevent this?

**Answer:**
**Diagnosis**:
```bash
# Check eviction reason
kubectl describe pod <pod-name> | grep -A5 Events

# Check node conditions
kubectl describe node <node-name> | grep -A5 Conditions

# Check node resource usage
kubectl top node <node-name>
```

**Solutions**:
1. **Add resource requests** — Guaranteed QoS pods are evicted last
2. **Set pod priority** — higher priority pods are evicted last
3. **Use PodDisruptionBudget** — prevents voluntary disruptions
4. **Add node capacity** — scale up or add nodes
5. **Move to dedicated node** — use taints/tolerations
6. **Implement VPA** — right-size requests to match actual usage

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: critical
value: 1000000
globalDefault: false
description: "Critical production workloads"
```

---

## Quick Reference: Commands Cheat Sheet

```bash
# Pod debugging
kubectl describe pod <pod>
kubectl logs <pod> --previous
kubectl exec -it <pod> -- sh
kubectl top pods --sort-by=memory

# Service debugging
kubectl get endpoints <svc>
kubectl run test --rm -it --image=busybox -- wget http://<svc>

# Node debugging
kubectl describe node <node>
kubectl drain <node> --ignore-daemonsets
kubectl cordon <node>

# Deployment debugging
kubectl rollout status deployment/<name>
kubectl rollout undo deployment/<name>
kubectl rollout history deployment/<name>

# RBAC debugging
kubectl auth can-i --list
kubectl auth can-i create pods -n <ns>

# Events
kubectl get events --sort-by='.lastTimestamp'

# Cluster health
kubectl get nodes
kubectl get pods -A --field-selector=status.phase!=Running
```

---

## Interview Tips

1. **Think out loud** — explain your reasoning, not just commands
2. **Start with symptoms** — describe what you observe before jumping to solutions
3. **Use the diagnostic toolkit**: `describe`, `logs`, `get events`, `exec`
4. **Know the difference**: liveness vs readiness, requests vs limits, Deployment vs StatefulSet
5. **Production mindset** — always consider rollback, monitoring, and prevention
6. **Admit uncertainty** — "I'm not sure, but I would check..." is better than guessing
7. **Reference real experience** — "In my previous environment, we encountered..."
8. **Ask clarifying questions** — "Is this a new deployment or existing?" "What's the error message?"

---

*Sources: Reddit r/kubernetes, CKAD practice exams, KORE1, DataCamp, Spacelift, LivingDevOps, candidate-reported interview rounds (2025-2026). Compiled for interview preparation.*
