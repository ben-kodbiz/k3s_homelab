output "network_name" {
  value = libvirt_network.lab_net.name
}

output "network_id" {
  value = libvirt_network.lab_net.id
}

output "network_cidr" {
  value = var.network_cidr
}

output "gateway_ip" {
  value = cidrhost(var.network_cidr, 1)
}
