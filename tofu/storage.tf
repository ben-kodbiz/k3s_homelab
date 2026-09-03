resource "libvirt_volume" "base" {
  name   = "k3s-lab-base-debian12.qcow2"
  pool   = var.pool_name
  source = var.base_image_url
  format = "qcow2"
}
