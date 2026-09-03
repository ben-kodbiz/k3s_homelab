variable "vm_name" {
  type        = string
  description = "libvirt domain name, e.g. cp01-cluster-a"
}

variable "vm_hostname" {
  type        = string
  description = "Guest hostname, e.g. cp01"
}

variable "memory_mb" {
  type    = number
  default = 2048
}

variable "vcpu" {
  type    = number
  default = 2
}

variable "pool_name" {
  type    = string
  default = "default"
}

variable "pool_path" {
  type    = string
  default = "/var/lib/libvirt/images"
}

variable "network_name" {
  type        = string
  description = "libvirt network name for the NIC"
}

variable "network_id" {
  type    = string
  default = null
}

variable "static_ips" {
  type        = list(string)
  description = "Deterministic static IPs (rendered into network-config)"
}

variable "mac_address" {
  type    = string
  default = null
}

variable "disk_gb" {
  type        = number
  default     = null
  description = "Optional: grow the cloned root disk to this size before first boot"
}

variable "base_volume_name" {
  type        = string
  description = "Pool volume name of base image to clone"
}

variable "user_data" {
  type        = string
  description = "cloud-init user-data (rendered by caller)"
}

variable "network_config" {
  type        = string
  default     = null
  description = "cloud-init network-config (static IP rendering)"
}
