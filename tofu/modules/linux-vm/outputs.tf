output "domain_name" {
  value = var.vm_name
}

output "static_ip" {
  value = var.static_ips[0]
}

output "vm_id" {
  value = null_resource.vm.id
}
