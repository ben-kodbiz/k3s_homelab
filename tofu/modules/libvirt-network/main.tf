terraform {
  required_version = ">= 1.6"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
    }
  }
}

resource "libvirt_network" "lab_net" {
  name      = var.network_name
  mode      = "nat"
  addresses = [var.network_cidr]
  domain    = var.dns_domain

  dns {
    enabled    = true
    local_only = true

    dynamic "hosts" {
      for_each = var.dns_hosts
      content {
        hostname = hosts.value.hostname
        ip       = hosts.value.ip
      }
    }
  }

  autostart = true
}
