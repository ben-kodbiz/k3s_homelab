terraform {
  required_version = ">= 1.6"
}

locals {
  hostname = var.rancher_hostname != "" ? var.rancher_hostname : "rancher.lab"
  ssh_cmd  = "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o UserKnownHostsFile=/dev/null -i ${var.ssh_key} ${var.ssh_user}@${var.cluster_ip}"
}

resource "null_resource" "rancher_deploy" {
  triggers = {
    rancher_version    = var.rancher_version
    cert_manager_version = var.cert_manager_version
    hostname           = local.hostname
    bootstrap_password = var.bootstrap_password
  }

  connection {
    type        = "ssh"
    host        = var.cluster_ip
    user        = var.ssh_user
    private_key = file(var.ssh_key)
  }

  # Add Helm repos and install cert-manager + Rancher
  provisioner "remote-exec" {
    inline = [
      "set -e",

      # Ensure Helm is installed
      "command -v helm >/dev/null 2>&1 || curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash",

      # Add repos
      "helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true",
      "helm repo add rancher-latest https://releases.rancher.com/server-charts/latest 2>/dev/null || true",
      "helm repo update",

      # Create namespace
      "kubectl create namespace ${var.rancher_namespace} 2>/dev/null || true",

      # Install cert-manager
      "helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version ${var.cert_manager_version} --set crds.enabled=true --wait --timeout 5m",

      # Wait for cert-manager
      "kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=120s",

      # Create self-signed issuer and certificate
      "cat <<'CERT_YAML' | kubectl apply -f -",
      "apiVersion: cert-manager.io/v1",
      "kind: ClusterIssuer",
      "metadata:",
      "  name: self-signed-issuer",
      "spec:",
      "  selfSigned: {}",
      "---",
      "apiVersion: cert-manager.io/v1",
      "kind: Certificate",
      "metadata:",
      "  name: tls-rancher-ingress",
      "  namespace: ${var.rancher_namespace}",
      "spec:",
      "  secretName: tls-rancher-ingress",
      "  dnsNames:",
      "  - ${local.hostname}",
      "  issuerRef:",
      "    name: self-signed-issuer",
      "    kind: ClusterIssuer",
      "  commonName: ${local.hostname}",
      "CERT_YAML",

      # Install Rancher
      "helm upgrade --install rancher rancher-latest/rancher --namespace ${var.rancher_namespace} --version ${var.rancher_version} --set hostname=${local.hostname} --set bootstrapPassword=${var.bootstrap_password} --set ingress.tls.source=rancher --set replicas=1 --wait --timeout 10m",

      # Wait for Rancher
      "kubectl -n ${var.rancher_namespace} rollout status deployment/rancher --timeout=300s",

      "echo 'Rancher deployed successfully'"
    ]
  }
}

# Retrieve bootstrap password
resource "null_resource" "rancher_bootstrap" {
  depends_on = [null_resource.rancher_deploy]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = var.cluster_ip
      user        = var.ssh_user
      private_key = file(var.ssh_key)
    }

    inline = [
      "kubectl get secret --namespace ${var.rancher_namespace} bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{printf \"\\n\"}}'"
    ]
  }
}
