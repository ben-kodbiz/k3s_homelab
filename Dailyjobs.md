# Daily Kubernetes Engineer Scenarios

## Lab Information
- **Cluster A**: `10.21.10.11` (3 servers + 3 workers)
- **Cluster B**: `10.21.20.11` (3 servers + 3 workers)
- **CNI**: Cilium
- **Ingress**: None (use NodePort/LoadBalancer)
- **Storage**: local-path-provisioner
- **SSH**: `ssh debian@10.21.10.{11-23}`

---

## Part 1: Getting Started (1-5)

### Scenario 1: Connect to Your First Cluster
**Objective**: Access the Kubernetes cluster from your workstation

```bash
# Get kubeconfig from cluster
ssh debian@10.21.10.11 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/config

# Fix server address
sed -i 's/127.0.0.1:6443/10.21.10.11:6443/g' ~/.kube/config

# Verify connection
kubectl cluster-info
kubectl get nodes
```

---

### Scenario 2: Understand Cluster Components
**Objective**: Explore all namespaces and system components

```bash
# List all namespaces
kubectl get namespaces

# List all pods in kube-system (control plane)
kubectl get pods -n kube-system -o wide

# List all pods across all namespaces
kubectl get pods -A

# Check component status
kubectl get componentstatuses
```

**Exercise**: Write down what each kube-system pod does:
- `coredns`: _______________
- `cilium-*`: _______________
- `metrics-server`: _______________

---

### Scenario 3: Navigate with kubectx and kubens
**Objective**: Master namespace and context switching

```bash
# List all contexts
kubectx

# Switch context
kubectx cluster-a

# List all namespaces
kubens

# Switch namespace
kubens kube-system

# Switch back to default
kubens default

# Quick namespace switch
kubectl -n monitoring get pods
```

---

### Scenario 4: Explore Resource Types
**Objective**: Learn to discover available resources

```bash
# List all resource types
kubectl api-resources

# List resources with their short names
kubectl api-resources | grep -E "NAME|SHORTNAMES"

# Get all resources in a namespace
kubectl get all -n kube-system

# Get resources with labels
kubectl get pods -n kube-system --show-labels
```

---

### Scenario 5: View Cluster Information
**Objective**: Understand cluster topology

```bash
# Cluster version and endpoints
kubectl cluster-info

# Node details
kubectl describe node cp01

# Master node taints (why pods don't schedule there)
kubectl describe node cp01 | grep -A5 Taints

# Worker node labels
kubectl label node wk01 --list
```

---

## Part 2: Pod Operations (6-10)

### Scenario 6: Create a Debug Pod
**Objective**: Launch a temporary pod for debugging

```bash
# One-liner debug pod
kubectl run debug --rm -it --image=alpine -- sh

# Inside the pod, test connectivity
ping 10.45.0.1           # CoreDNS
nslookup kubernetes.default
curl -k https://kubernetes.default.svc:443

# Exit pod
exit
```

---

### Scenario 7: Run a Pod with Specific Resources
**Objective**: Create a pod with CPU/memory limits

```yaml
# save as pod-resources.yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        cpu: "100m"        # 0.1 CPU core
        memory: "64Mi"
      limits:
        cpu: "500m"        # 0.5 CPU core
        memory: "128Mi"
```

```bash
kubectl apply -f pod-resources.yaml

# Watch resource usage
kubectl top pod resource-demo

# Verify limits
kubectl describe pod resource-demo | grep -A4 Limits

# Cleanup
kubectl delete pod resource-demo
```

---

### Scenario 8: Debug a CrashLooping Pod
**Objective**: Diagnose why a pod keeps restarting

```bash
# Deploy a broken pod
kubectl run broken-app --image=nginx:alpine -- sh -c "exit 1"

# Watch it crash
kubectl get pods -w

# Check logs (even from previous crashes)
kubectl logs broken-app --previous

# Describe pod for events
kubectl describe pod broken-app | grep -A10 Events

# Cleanup
kubectl delete pod broken-app
```

---

### Scenario 9: Execute Commands Inside Running Pods
**Objective**: Access and debug running containers

```bash
# Run nginx
kubectl run nginx-test --image=nginx:alpine

# Wait for it to be ready
kubectl wait --for=condition=Ready pod/nginx-test

# Execute a command
kubectl exec nginx-test -- cat /etc/nginx/nginx.conf

# Interactive shell
kubectl exec -it nginx-test -- sh

# Inside shell:
#   ls /usr/share/nginx/html/
#   echo "hello" > /usr/share/nginx/html/index.html
#   exit

# Cleanup
kubectl delete pod nginx-test
```

---

### Scenario 10: Understand Pod Scheduling
**Objective**: See how pods are distributed across nodes

```bash
# Create multiple pods
for i in {1..6}; do
  kubectl run pod-$i --image=nginx:alpine
done

# Watch scheduling
kubectl get pods -o wide

# Check node capacity
kubectl describe nodes | grep -A5 "Allocated resources"

# Taint a worker (prevent scheduling)
kubectl taint nodes wk01 dedicated=gpu:NoSchedule

# Try to schedule on tainted node
kubectl run test-taint --image=nginx:alpine

# Remove taint
kubectl taint nodes wk01 dedicated:NoSchedule-

# Cleanup
kubectl delete pods --all
```

---

## Part 3: Deployments & ReplicaSets (11-15)

### Scenario 11: Create a Deployment
**Objective**: Deploy a scalable application

```yaml
# save as web-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
  labels:
    app: web-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-server
  template:
    metadata:
      labels:
        app: web-server
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f web-deployment.yaml

# Verify deployment
kubectl get deployment web-server
kubectl get replicaset
kubectl get pods -l app=web-server
```

---

### Scenario 12: Rolling Updates with Zero Downtime
**Objective**: Update application without service interruption

```bash
# Current version
kubectl set image deployment/web-server nginx=nginx:1.20

# Watch the rollout
kubectl rollout status deployment/web-server

# Verify all pods updated
kubectl get pods -l app=web-server

# Check rollout history
kubectl rollout history deployment/web-server
```

---

### Scenario 13: Rollback a Failed Deployment
**Objective**: Recover from a bad deployment

```bash
# Deploy a broken version
kubectl set image deployment/web-server nginx=nginx:nonexistent

# Watch it fail
kubectl get pods -l app=web-server

# Rollback to previous
kubectl rollout undo deployment/web-server

# Verify recovery
kubectl rollout status deployment/web-server
```

---

### Scenario 14: Scale Deployments
**Objective**: Manually scale and autoscale

```bash
# Manual scale
kubectl scale deployment web-server --replicas=5

# Watch pods come up
kubectl get pods -l app=web-server -w

# Scale down
kubectl scale deployment web-server --replicas=2
```

---

### Scenario 15: Pause and Resume Deployments
**Objective**: Make multiple changes without triggering rollouts

```bash
# Pause the deployment
kubectl rollout pause deployment/web-server

# Make multiple changes
kubectl set image deployment/web-server nginx=nginx:1.21
kubectl set resources deployment/web-server --limits=cpu=200m

# Resume (triggers single rollout)
kubectl rollout resume deployment/web-server

# Verify
kubectl rollout status deployment/web-server
```

---

## Part 4: Services & Networking (16-20)

### Scenario 16: Create a ClusterIP Service
**Objective**: Expose pods internally within the cluster

```yaml
# save as web-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: ClusterIP
  selector:
    app: web-server
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f web-service.yaml

# Verify service
kubectl get svc web-service

# Test from inside cluster
kubectl run test --rm -it --image=alpine -- wget -qO- http://web-service
```

---

### Scenario 17: Create a NodePort Service
**Objective**: Expose service externally via node IP

```yaml
# save as web-nodeport.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector:
    app: web-server
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

```bash
kubectl apply -f web-nodeport.yaml

# Test from workstation
curl http://10.21.10.11:30080
```

---

### Scenario 18: DNS Resolution in Cluster
**Objective**: Understand Kubernetes DNS

```bash
# Launch debug pod
kubectl run dns-test --rm -it --image=alpine -- sh

# Inside the pod:
nslookup web-service
nslookup web-service.default.svc.cluster.local
nslookup kubernetes.default.svc.cluster.local

# Test full FQDN
nslookup kube-dns.kube-system.svc.cluster.local

# Exit
exit
```

---

### Scenario 19: Network Policies (Cilium)
**Objective**: Restrict pod-to-pod communication

```yaml
# save as deny-all.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  endpointSelector: {}
  ingress: []
  egress: []
```

```bash
# Deploy nginx
kubectl run nginx-net --image=nginx:alpine
kubectl expose pod nginx-net --port=80

# Test (should work)
kubectl run test --rm -it --image=alpine -- wget -qO- http://nginx-net

# Apply deny-all policy
kubectl apply -f deny-all.yaml

# Test again (should timeout)
kubectl run test2 --rm -it --image=alpine -- wget -qO- --timeout=5 http://nginx-net

# Cleanup
kubectl delete -f deny-all.yaml
kubectl delete pod nginx-net
kubectl delete svc nginx-net
```

---

### Scenario 20: Port Forwarding
**Objective**: Access pods directly from workstation

```bash
# Port forward a pod
kubectl port-forward pod/web-server-xxxxx 8080:80

# In another terminal
curl http://localhost:8080

# Port forward a service
kubectl port-forward svc/web-service 8080:80

# Stop with Ctrl+C
```

---

## Part 5: Storage & PVCs (21-25)

### Scenario 21: Create a PersistentVolumeClaim
**Objective**: Request storage for stateful workloads

```yaml
# save as test-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
```

```bash
kubectl apply -f test-pvc.yaml

# Verify PVC is bound
kubectl get pvc test-pvc

# Check PV created
kubectl get pv
```

---

### Scenario 22: Mount Storage in a Pod
**Objective**: Use PVC to persist data

```yaml
# save as test-pod-with-pvc.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-storage
spec:
  containers:
  - name: app
    image: nginx:alpine
    volumeMounts:
    - name: data
      mountPath: /usr/share/nginx/html
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-pvc
```

```bash
kubectl apply -f test-pod-with-pvc.yaml

# Write data
kubectl exec test-storage -- sh -c "echo 'Hello PVC' > /usr/share/nginx/html/index.html"

# Verify data persists (restart pod)
kubectl delete pod test-storage
kubectl apply -f test-pod-with-pvc.yaml

# Check data still exists
kubectl exec test-storage -- cat /usr/share/nginx/html/index.html
# Should output: Hello PVC
```

---

### Scenario 23: Scale Pods with Shared Storage
**Objective**: Multiple pods read from same PVC

```yaml
# save as shared-storage.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shared-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: shared
  template:
    metadata:
      labels:
        app: shared
    spec:
      containers:
      - name: app
        image: nginx:alpine
        volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: test-pvc
```

```bash
kubectl apply -f shared-storage.yaml

# Check all pods can see the data
kubectl exec -it deploy/shared-app -- cat /usr/share/nginx/html/index.html
```

---

### Scenario 24: Storage Class Exploration
**Objective**: Understand storage options

```bash
# List storage classes
kubectl get sc

# Describe storage class
kubectl describe sc local-path

# Check PV details
kubectl describe pv
```

---

### Scenario 25: Clean Up Storage
**Objective**: Properly remove PVCs and PVs

```bash
# Delete pod first
kubectl delete pod test-storage

# Delete PVC
kubectl delete pvc test-pvc

# Verify PV is released
kubectl get pv

# Delete deployment
kubectl delete deployment shared-app
```

---

## Part 6: ConfigMaps & Secrets (26-30)

### Scenario 26: Create a ConfigMap from Literals
**Objective**: Store configuration data

```bash
# Create from literals
kubectl create configmap app-config \
  --from-literal=DATABASE_HOST=postgres.default.svc \
  --from-literal=DATABASE_PORT=5432 \
  --from-literal=LOG_LEVEL=debug

# Verify
kubectl get configmap app-config
kubectl describe configmap app-config

# Use in pod
kubectl run test-config --rm -it --image=alpine -- sh -c "echo \$DATABASE_HOST"
```

---

### Scenario 27: Create ConfigMap from File
**Objective**: Load configuration from files

```bash
# Create a config file
cat > app.properties <<EOF
spring.profiles.active=production
server.port=8080
logging.level.root=INFO
EOF

# Create ConfigMap from file
kubectl create configmap app-props --from-file=app.properties

# Mount in pod
kubectl run config-test --rm -it --image=alpine \
  --overrides='{"spec":{"containers":[{"name":"config-test","image":"alpine","command":["cat","/config/app.properties"],"volumeMounts":[{"name":"config","mountPath":"/config"}]}],"volumes":[{"name":"config","configMap":{"name":"app-props"}}]}}' \
  -- sh

# Cleanup
kubectl delete configmap app-config app-props
```

---

### Scenario 28: Create and Use Secrets
**Objective**: Store sensitive data securely

```bash
# Create secret from literal
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password='S3cr3tP@ss!'

# Verify (base64 encoded)
kubectl get secret db-secret -o yaml

# Decode
kubectl get secret db-secret -o jsonpath='{.data.password}' | base64 -d

# Use in pod via environment variable
kubectl run secret-test --rm -it --image=alpine \
  --overrides='{"spec":{"containers":[{"name":"secret-test","image":"alpine","env":[{"name":"DB_USER","valueFrom":{"secretKeyRef":{"name":"db-secret","key":"username"}}},{"name":"DB_PASS","valueFrom":{"secretKeyRef":{"name":"db-secret","key":"password"}}}]}]}}' \
  -- env
```

---

### Scenario 29: Mount Secrets as Files
**Objective**: Access secrets as mounted volumes

```yaml
# save as secret-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-file-test
spec:
  containers:
  - name: app
    image: alpine
    command: ["sh", "-c", "cat /secret/username && cat /secret/password"]
    volumeMounts:
    - name: secrets
      mountPath: /secret
      readOnly: true
  volumes:
  - name: secrets
    secret:
      secretName: db-secret
```

```bash
kubectl apply -f secret-pod.yaml

# Check logs for secret values
kubectl logs secret-file-test

# Cleanup
kubectl delete -f secret-pod.yaml
kubectl delete secret db-secret
```

---

### Scenario 30: Hot Reload ConfigMaps
**Objective**: Update configuration without restarting pods

```bash
# Create configmap
kubectl create configmap hot-reload --from-literal=message="Version 1"

# Deploy app that reads from configmap
kubectl run hot-app --image=nginx:alpine

# Update configmap
kubectl create configmap hot-reload --from-literal=message="Version 2" --dry-run=client -o yaml | kubectl apply -f -

# Note: Pods must re-read the file; for env vars, pod restart needed
# For file mounts, pods see updated files within seconds

# Cleanup
kubectl delete pod hot-app
kubectl delete configmap hot-reload
```

---

## Part 7: RBAC & Security (31-35)

### Scenario 31: View Current RBAC Permissions
**Objective**: Understand what you can do

```bash
# Check your permissions
kubectl auth can-i --list

# Check specific permissions
kubectl auth can-i create pods
kubectl auth can-i delete namespaces
kubectl auth can-i get pods -n monitoring

# Check as specific user
kubectl auth can-i list deployments --as=system:serviceaccount:default:default
```

---

### Scenario 32: Create a ServiceAccount
**Objective**: Create identity for pods

```bash
# Create service account
kubectl create serviceaccount my-app

# Verify
kubectl get serviceaccount my-app

# Check secrets
kubectl get secret | grep my-app
```

---

### Scenario 33: Create a Role and RoleBinding
**Objective**: Grant specific permissions

```yaml
# save as pod-reader-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]
```

```bash
kubectl apply -f pod-reader-role.yaml

# Bind to service account
kubectl create rolebinding my-app-pod-reader \
  --role=pod-reader \
  --serviceaccount=default:my-app

# Test permissions
kubectl auth can-i list pods --as=system:serviceaccount:default:my-app
kubectl auth can-i delete pods --as=system:serviceaccount:default:my-app
```

---

### Scenario 34: Create a ClusterRole (Cluster-Wide)
**Objective**: Grant permissions across all namespaces

```yaml
# save as secret-reader-clusterrole.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
```

```bash
kubectl apply -f secret-reader-clusterrole.yaml

# Bind to user across all namespaces
kubectl create clusterrolebinding my-app-secret-reader \
  --clusterrole=secret-reader \
  --serviceaccount=default:my-app

# Test
kubectl auth can-i list secrets -A --as=system:serviceaccount:default:my-app
```

---

### Scenario 35: Network Policies with Cilium
**Objective**: Implement micro-segmentation

```yaml
# save as allow-web-only.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-web-only
  namespace: default
spec:
  endpointSelector:
    matchLabels:
      app: web-server
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
  egress:
  - toEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: kube-system
        k8s-app: kube-dns
    toPorts:
    - ports:
      - port: "53"
        protocol: UDP
```

```bash
kubectl apply -f allow-web-only.yaml

# Test: client pod can reach web
kubectl run client --labels=app=client --image=alpine -- wget -qO- http://web-service

# Test: other pods cannot
kubectl run attacker --image=alpine -- wget -qO- --timeout=5 http://web-service

# Cleanup
kubectl delete -f allow-web-only.yaml
```

---

## Part 8: Monitoring & Debugging (36-40)

### Scenario 36: Check Pod Logs
**Objective**: Access application logs

```bash
# View logs
kubectl logs web-server-xxxxx

# Follow logs in real-time
kubectl logs -f web-server-xxxxx

# View previous container logs (after crash)
kubectl logs web-server-xxxxx --previous

# View logs from all pods with label
kubectl logs -l app=web-server --all-containers

# View last 50 lines
kubectl logs --tail=50 web-server-xxxxx
```

---

### Scenario 37: Debug with kubectl debug
**Objective**: Use ephemeral containers for debugging

```bash
# Add debug container to running pod
kubectl debug -it web-server-xxxxx --image=busybox --target=nginx

# Inside debug container:
#   wget -qO- http://localhost:80
#   netstat -tlnp
#   cat /etc/nginx/nginx.conf
#   exit

# View node-level processes
kubectl debug node/wk01 -it --image=busybox

# Inside node debug:
#   ls /proc
#   ps aux | grep kubelet
#   exit
```

---

### Scenario 38: Use Metrics Server
**Objective**: Monitor resource usage

```bash
# View pod resource usage
kubectl top pods

# View node resource usage
kubectl top nodes

# View specific namespace
kubectl top pods -n kube-system

# Sort by CPU
kubectl top pods --sort-by=cpu

# Sort by memory
kubectl top pods --sort-by=memory

# Continuous monitoring
kubectl top pods -w
```

---

### Scenario 39: Event Analysis
**Objective**: Understand cluster events

```bash
# View all events
kubectl get events --sort-by='.lastTimestamp'

# View events for specific pod
kubectl describe pod web-server-xxxxx | grep -A10 Events

# View warning events
kubectl get events --field-selector type=Warning

# View events in specific namespace
kubectl get events -n monitoring
```

---

### Scenario 40: Full Application Debug
**Objective**: Complete troubleshooting workflow

**Problem**: Application is slow

```bash
# Step 1: Check pod status
kubectl get pods -l app=web-server -o wide

# Step 2: Check resource usage
kubectl top pods -l app=web-server

# Step 3: Check node resources
kubectl top nodes

# Step 4: Check pod logs
kubectl logs -l app=web-server --tail=100

# Step 5: Check events
kubectl get events --sort-by='.lastTimestamp' | head -20

# Step 6: Check network
kubectl run test --rm -it --image=alpine -- wget -qO- --timeout=5 http://web-service

# Step 7: Check storage
kubectl get pvc
kubectl describe pvc test-pvc

# Step 8: Check DNS
kubectl run dns-test --rm -it --image=alpine -- nslookup web-service

# Step 9: Check node conditions
kubectl get nodes -o wide

# Step 10: Check component health
kubectl get componentstatuses
```

---

## Part 9: Cluster Operations (41-45)

### Scenario 41: Backup etcd
**Objective**: Backup cluster state

```bash
# On control plane node
ssh debian@10.21.10.11

# Backup etcd
sudo etcdctl snapshot save /tmp/etcd-backup-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key

# Verify backup
sudo etcdctl snapshot status /tmp/etcd-backup-*.db --write-table
```

---

### Scenario 42: Drain and Cordon Nodes
**Objective**: Safely perform maintenance

```bash
# Cordon node (prevent new pods)
kubectl cordon wk01

# Drain node (move pods elsewhere)
kubectl drain wk01 --ignore-daemonsets --delete-emptydir-data

# Perform maintenance (e.g., OS update)
ssh debian@10.21.10.21 'sudo apt update && sudo apt upgrade -y'

# Uncordon node (allow scheduling again)
kubectl uncordon wk01

# Verify
kubectl get nodes
```

---

### Scenario 43: Resource Quotas
**Objective**: Limit resource consumption per namespace

```yaml
# save as resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: default
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "20"
```

```bash
kubectl apply -f resource-quota.yaml

# Check quota usage
kubectl get resourcequota compute-quota

# Try to create pod exceeding quota
kubectl run big-pod --image=nginx --overrides='{"spec":{"containers":[{"name":"big-pod","image":"nginx","resources":{"limits":{"cpu":"5","memory":"10Gi"}}}]}}'

# Cleanup
kubectl delete -f resource-quota.yaml
```

---

### Scenario 44: Limit Ranges
**Objective**: Set default resource limits per pod

```yaml
# save as limit-range.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: default
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
```

```bash
kubectl apply -f limit-range.yaml

# Create pod without resource spec (gets defaults)
kubectl run default-pod --image=nginx

# Verify defaults applied
kubectl describe pod default-pod | grep -A4 Limits

# Cleanup
kubectl delete pod default-pod
kubectl delete -f limit-range.yaml
```

---

### Scenario 45: Cluster Health Check Script
**Objective**: Automate health monitoring

```bash
cat > cluster-health.sh <<'EOF'
#!/bin/bash
echo "=== Cluster Health Check ==="
echo ""
echo "--- Nodes ---"
kubectl get nodes -o wide
echo ""
echo "--- Pods Not Ready ---"
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
echo ""
echo "--- Resource Usage ---"
kubectl top nodes
kubectl top pods -A --sort-by=memory | head -10
echo ""
echo "--- Recent Events ---"
kubectl get events --sort-by='.lastTimestamp' --no-headers | tail -10
echo ""
echo "--- Component Status ---"
kubectl get componentstatuses 2>/dev/null || kubectl get --raw='/readyz?verbose' 2>/dev/null
EOF

chmod +x cluster-health.sh
./cluster-health.sh
```

---

## Cleanup Guide

### Remove Test Resources
```bash
# Delete all test deployments/pods/services
kubectl delete deployment --all
kubectl delete pod --all
kubectl delete svc --all
kubectl delete pvc --all
kubectl delete configmap --all
kubectl delete secret --all
kubectl delete role --all
kubectl delete rolebinding --all
kubectl delete clusterrole --all
kubectl delete clusterrolebinding --all
kubectl delete serviceaccount --all
```

### Restore to Original State
```bash
# Verify only original workloads remain
kubectl get all -A
kubectl get nodes
```

---

## Quick Reference

### kubectl Commands
| Command | Description |
|---------|-------------|
| `kubectl get pods -o wide` | List pods with node and IP |
| `kubectl describe pod <name>` | Detailed pod info |
| `kubectl logs <pod>` | View pod logs |
| `kubectl exec -it <pod> -- sh` | Interactive shell |
| `kubectl apply -f <file>` | Create/update from YAML |
| `kubectl delete -f <file>` | Delete from YAML |
| `kubectl top pods` | Resource usage |
| `kubectl get events --sort-by=.lastTimestamp` | Recent events |
| `kubectl rollout status deployment/<name>` | Watch rollout |
| `kubectl rollout undo deployment/<name>` | Rollback |

### Useful Flags
| Flag | Description |
|------|-------------|
| `-A` or `--all-namespaces` | All namespaces |
| `-l <label>` | Filter by label |
| `-o wide` | More details |
| `-o yaml` | Output as YAML |
| `-o jsonpath='{.spec}'` | Extract specific field |
| `--field-selector` | Filter by field |
| `--watch` or `-w` | Watch for changes |
| `--dry-run=client` | Don't apply, just show |

---

## Learning Path

**Beginner (Scenarios 1-15)**: Core concepts, pods, deployments
**Intermediate (Scenarios 16-35)**: Services, storage, RBAC, networking
**Advanced (Scenarios 36-45)**: Debugging, monitoring, cluster operations

## Next Steps

After completing all scenarios:
1. Deploy a real application (nginx + database)
2. Set up monitoring (Prometheus + Grafana)
3. Implement CI/CD (ArgoCD)
4. Practice failure scenarios (node failure, pod eviction)
5. Explore Cilium advanced features (Hubble, service mesh)
