variable "network_name" {
  type        = string
  default     = "k3s-lab-net"
  description = "libvirt network name (must be project-unique)"
}

variable "network_cidr" {
  type        = string
  default     = "10.21.0.0/16"
  description = "NAT network CIDR. Must not overlap host LAN / other networks."
}

variable "dns_domain" {
  type    = string
  default = "k3s.lab"
}

variable "dns_hosts" {
  type = list(object({
    hostname = string
    ip       = string
  }))
  default     = []
  description = "Static dnsmasq A records"
}
