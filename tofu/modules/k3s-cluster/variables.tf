variable "cluster_name" {
  type = string
}

variable "cluster_subnet" {
  type        = string
  description = "e.g. 10.21.10.0/24"
}

variable "api_vip" {
  type = string
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

variable "worker_count" {
  type    = number
  default = 3
}

variable "control_plane_vcpu" {
  type    = number
  default = 2
}

variable "control_plane_memory_mb" {
  type    = number
  default = 2048
}

variable "control_plane_disk_gb" {
  type    = number
  default = 20
}

variable "worker_vcpu" {
  type    = number
  default = 2
}

variable "worker_memory_mb" {
  type    = number
  default = 1536
}

variable "worker_disk_gb" {
  type    = number
  default = 15
}

variable "k3s_version" {
  type = string
}

variable "cluster_token" {
  type      = string
  sensitive = true
}

variable "cluster_cidr" {
  type    = string
  default = "10.44.0.0/16"
}

variable "service_cidr" {
  type    = string
  default = "10.45.0.0/16"
}

variable "vm_password" {
  type        = string
  default     = "changeme"
  description = "Password for debian and root users on VMs"
  sensitive   = true
}
