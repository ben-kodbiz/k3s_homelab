terraform {
  required_version = ">= 1.6"
}

locals {
  cp_nodes = [
    for i in range(var.control_plane_count) : {
      hostname         = format("cp%02d", i + 1)
      ip               = cidrhost(var.cluster_subnet, 11 + i)
      is_first_server  = (i == 0)
      server_url       = (i == 0) ? "" : "https://${cidrhost(var.cluster_subnet, 11)}:6443"
    }
  ]
  worker_nodes = [
    for i in range(var.worker_count) : {
      hostname = format("wk%02d", i + 1)
      ip       = cidrhost(var.cluster_subnet, 21 + i)
    }
  ]
  all_nodes = concat(local.cp_nodes, local.worker_nodes)
}

resource "null_resource" "vip_guard" {
  count = contains([for n in local.all_nodes : n.ip], var.api_vip) ? 1 : 0
  provisioner "local-exec" {
    command = "echo 'ERROR: api_vip collides with a node IP' && exit 1"
  }
}

module "control_plane" {
  source   = "../cluster-node"
  for_each = { for n in local.cp_nodes : n.hostname => n }

  cluster_name       = var.cluster_name
  hostname           = each.key
  role               = "server"
  static_ip          = each.value.ip
  gateway_ip         = var.gateway_ip
  network_id         = var.network_id
  network_name       = var.network_name
  pool_name          = var.pool_name
  pool_path          = var.pool_path
  memory_mb          = var.control_plane_memory_mb
  vcpu               = var.control_plane_vcpu
  disk_size_gb       = var.control_plane_disk_gb
  k3s_version        = var.k3s_version
  cluster_token      = var.cluster_token
  api_vip            = var.api_vip
  ssh_pubkeys        = var.ssh_pubkeys
  base_volume_name   = var.base_volume_name
  cluster_cidr       = var.cluster_cidr
  service_cidr       = var.service_cidr
  control_plane_count = var.control_plane_count
  is_first_server    = each.value.is_first_server
  server_url         = each.value.server_url
  vm_password        = var.vm_password
}

module "worker" {
  source   = "../cluster-node"
  for_each = { for n in local.worker_nodes : n.hostname => n }

  cluster_name       = var.cluster_name
  hostname           = each.key
  role               = "agent"
  static_ip          = each.value.ip
  gateway_ip         = var.gateway_ip
  network_id         = var.network_id
  network_name       = var.network_name
  pool_name          = var.pool_name
  pool_path          = var.pool_path
  memory_mb          = var.worker_memory_mb
  vcpu               = var.worker_vcpu
  disk_size_gb       = var.worker_disk_gb
  k3s_version        = var.k3s_version
  cluster_token      = var.cluster_token
  api_vip            = var.api_vip
  ssh_pubkeys        = var.ssh_pubkeys
  base_volume_name   = var.base_volume_name
  control_plane_count = var.control_plane_count
  vm_password        = var.vm_password
}
