locals {
  gateway_ip = cidrhost(var.network_cidr, 1)
}

module "cluster_a" {
  source = "./modules/k3s-cluster"

  count = var.cluster_a_enabled ? 1 : 0

  cluster_name        = "cluster-a"
  cluster_subnet      = var.cluster_a_subnet
  api_vip             = var.cluster_a_api_vip
  gateway_ip          = local.gateway_ip
  network_id          = module.network.network_id
  network_name        = module.network.network_name
  pool_name           = var.pool_name
  pool_path           = "/var/lib/libvirt/images"
  ssh_pubkeys         = var.ssh_pubkeys
  base_volume_name    = "k3s-lab-base-debian12.qcow2"
  control_plane_count = var.cluster_a_cp_count
  worker_count        = var.cluster_a_worker_count
  k3s_version         = var.k3s_version
  cluster_token       = var.cluster_a_token
  vm_password         = var.vm_password

  control_plane_memory_mb = coalesce(var.cluster_a_control_plane_memory_mb, var.control_plane_memory_mb)
  control_plane_vcpu      = coalesce(var.cluster_a_control_plane_vcpu, var.control_plane_vcpu)
  control_plane_disk_gb   = var.control_plane_disk_gb
  worker_memory_mb        = var.worker_memory_mb
  worker_vcpu             = var.worker_vcpu
  worker_disk_gb          = var.worker_disk_gb
}

module "cluster_b" {
  source = "./modules/k3s-cluster"

  count = var.cluster_b_enabled ? 1 : 0

  cluster_name        = "cluster-b"
  cluster_subnet      = var.cluster_b_subnet
  api_vip             = var.cluster_b_api_vip
  gateway_ip          = local.gateway_ip
  network_id          = module.network.network_id
  network_name        = module.network.network_name
  pool_name           = var.pool_name
  pool_path           = "/var/lib/libvirt/images"
  ssh_pubkeys         = var.ssh_pubkeys
  base_volume_name    = "k3s-lab-base-debian12.qcow2"
  control_plane_count = var.cluster_b_cp_count
  worker_count        = var.cluster_b_worker_count
  k3s_version         = var.k3s_version
  cluster_token       = var.cluster_b_token
  vm_password         = var.vm_password

  control_plane_memory_mb = var.control_plane_memory_mb
  control_plane_vcpu      = var.control_plane_vcpu
  control_plane_disk_gb   = var.control_plane_disk_gb
  worker_memory_mb        = var.worker_memory_mb
  worker_vcpu             = var.worker_vcpu
  worker_disk_gb          = var.worker_disk_gb
}
