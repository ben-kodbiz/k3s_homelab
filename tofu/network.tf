module "network" {
  source = "./modules/libvirt-network"

  network_name = var.network_name
  network_cidr = var.network_cidr
}
