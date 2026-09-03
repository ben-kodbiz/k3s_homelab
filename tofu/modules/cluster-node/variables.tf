variable "cluster_name" {
  type = string
}

variable "hostname" {
  type        = string
  description = "Short node name, e.g. cp01"
}

variable "role" {
  type        = string
  description = "server | agent"

  validation {
    condition     = contains(["server", "agent"], var.role)
    error_message = "role must be server or agent."
  }
}

variable "dns_domain" {
  type    = string
  default = "k3s.lab"
}

variable "static_ip" {
  type = string
}

variable "network_cidr_prefix" {
  type    = number
  default = 16
}

variable "gateway_ip" {
  type = string
}

variable "network_id" {
  type = string
}

variable "network_name" {
  type = string
}

variable "pool_name" {
  type = string
}

variable "pool_path" {
  type    = string
  default = "/var/lib/libvirt/images"
}

variable "memory_mb" {
  type = number
}

variable "vcpu" {
  type = number
}

variable "disk_size_gb" {
  type = number
}

variable "mac_address" {
  type    = string
  default = null
}

variable "k3s_version" {
  type = string
}

variable "cluster_token" {
  type      = string
  sensitive = true
}

variable "api_vip" {
  type = string
}

variable "cluster_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "service_cidr" {
  type    = string
  default = "10.43.0.0/16"
}

variable "ssh_pubkeys" {
  type = list(string)
}

variable "base_volume_name" {
  type = string
}

variable "control_plane_count" {
  type    = number
  default = 3
}

variable "is_first_server" {
  type        = bool
  default     = false
  description = "True if this is the first K3s server (uses --cluster-init)"
}

variable "server_url" {
  type        = string
  default     = ""
  description = "URL of existing K3s server to join (e.g. https://10.21.10.11:6443)"
}

variable "vm_password" {
  type        = string
  default     = "changeme"
  description = "Password for debian and root users on the VM"
  sensitive   = true
}
