terraform {
  required_version = ">= 1.6"
}

locals {
  hostname_fqdn = "${var.hostname}.${var.dns_domain}"

  network_config = <<-EOT
version: 2
ethernets:
  ens3:
    match:
      name: en*
    addresses:
      - ${var.static_ip}/${var.network_cidr_prefix}
    routes:
      - to: default
        via: ${var.gateway_ip}
    nameservers:
      addresses:
        - ${var.gateway_ip}
        - 1.1.1.1
      search:
        - ${var.dns_domain}
  EOT

  user_data = templatefile("${path.module}/templates/user-data-${var.role}.tftpl", {
    hostname        = var.hostname
    fqdn            = local.hostname_fqdn
    ssh_pubkeys     = var.ssh_pubkeys
    k3s_version     = var.k3s_version
    cluster_token   = var.cluster_token
    api_vip         = var.api_vip
    node_ip         = var.static_ip
    role            = var.role
    cluster_name    = var.cluster_name
    server_count    = var.control_plane_count
    cluster_cidr    = var.cluster_cidr
    service_cidr    = var.service_cidr
    tls_san         = var.api_vip
    is_first_server = var.is_first_server
    server_url      = var.server_url
    vm_password     = var.vm_password
  })
}

module "vm" {
  source = "../linux-vm"

  vm_name         = "${var.hostname}-${var.cluster_name}"
  vm_hostname     = var.hostname
  pool_name       = var.pool_name
  pool_path       = var.pool_path
  memory_mb       = var.memory_mb
  vcpu            = var.vcpu
  disk_gb         = var.disk_size_gb

  network_name    = var.network_name
  network_id      = var.network_id
  static_ips      = [var.static_ip]
  mac_address     = var.mac_address

  user_data      = local.user_data
  network_config = local.network_config

  base_volume_name = var.base_volume_name
}
