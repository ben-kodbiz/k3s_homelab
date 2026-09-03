variable "libvirt_uri" {
  type    = string
  default = "qemu:///system"
}

variable "network_name" {
  type    = string
  default = "k3s-lab-net"
}

variable "network_cidr" {
  type    = string
  default = "10.21.0.0/16"
}

variable "pool_name" {
  type    = string
  default = "default"
}

variable "base_image_url" {
  type    = string
  default = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
}

variable "ssh_pubkeys" {
  type    = list(string)
  default = []
}

variable "k3s_version" {
  type    = string
  default = "v1.31.4+k3s1"
}

variable "cluster_a_enabled" {
  type    = bool
  default = false
}

variable "cluster_a_subnet" {
  type    = string
  default = "10.21.10.0/24"
}

variable "cluster_a_api_vip" {
  type    = string
  default = "10.21.10.10"
}

variable "cluster_a_cp_count" {
  type    = number
  default = 3
}

variable "cluster_a_worker_count" {
  type    = number
  default = 3
}

variable "cluster_b_enabled" {
  type    = bool
  default = false
}

variable "cluster_b_subnet" {
  type    = string
  default = "10.21.20.0/24"
}

variable "cluster_b_api_vip" {
  type    = string
  default = "10.21.20.10"
}

variable "cluster_b_cp_count" {
  type    = number
  default = 3
}

variable "cluster_b_worker_count" {
  type    = number
  default = 3
}

variable "control_plane_disk_gb" {
  type    = number
  default = 20
}

variable "worker_disk_gb" {
  type    = number
  default = 15
}

variable "control_plane_memory_mb" {
  type    = number
  default = 2048
}

variable "worker_memory_mb" {
  type    = number
  default = 1536
}

variable "control_plane_vcpu" {
  type    = number
  default = 2
}

variable "worker_vcpu" {
  type    = number
  default = 2
}

variable "cluster_a_token" {
  type      = string
  sensitive = true
  default   = ""
  description = "K3s cluster token for Cluster A (generate before apply)"
}

variable "cluster_b_token" {
  type      = string
  sensitive = true
  default   = ""
  description = "K3s cluster token for Cluster B (generate before apply)"
}

variable "vm_password" {
  type        = string
  sensitive   = true
  default     = "changeme"
  description = "Password for debian and root users on all VMs"
}
