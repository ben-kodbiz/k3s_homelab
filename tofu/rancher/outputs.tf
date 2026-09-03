output "rancher_hostname" {
  value = local.hostname
}

output "rancher_namespace" {
  value = var.rancher_namespace
}

output "access_url" {
  value = "https://${local.hostname}"
}

output "port_forward_command" {
  value = "kubectl -n ${var.rancher_namespace} port-forward svc/rancher 8443:443"
}
