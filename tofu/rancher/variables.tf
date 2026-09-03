variable "cluster_ip" {
  type        = string
  description = "IP of the K3s control-plane node to deploy Rancher on"
}

variable "ssh_key" {
  type        = string
  default     = "/home/ben/.ssh/id_ed25519"
  description = "Path to SSH private key"
}

variable "ssh_user" {
  type    = string
  default = "debian"
}

variable "rancher_version" {
  type    = string
  default = "2.10.3"
}

variable "cert_manager_version" {
  type    = string
  default = "v1.17.1"
}

variable "bootstrap_password" {
  type      = string
  sensitive = true
  default   = "admin123"
}

variable "rancher_hostname" {
  type    = string
  default = ""
}

variable "rancher_namespace" {
  type    = string
  default = "cattle-system"
}
