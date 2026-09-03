terraform {
  required_version = ">= 1.6"
}

locals {
  create_script = abspath("${path.module}/../../../scripts/create-vm.sh")
  delete_script = abspath("${path.module}/../../../scripts/delete-vm.sh")
}

resource "local_file" "user_data" {
  content         = var.user_data
  filename        = "/tmp/k3s-lab-${var.vm_name}-user-data"
  file_permission = "0644"
}

resource "local_file" "network_config" {
  count           = var.network_config != null ? 1 : 0
  content         = var.network_config
  filename        = "/tmp/k3s-lab-${var.vm_name}-network-config"
  file_permission = "0644"
}

resource "null_resource" "vm" {
  triggers = {
    vm_name       = var.vm_name
    pool_name     = var.pool_name
    user_data     = var.user_data
    network_cfg   = coalesce(var.network_config, "-")
    delete_script = local.delete_script
  }

  provisioner "local-exec" {
    command = join(" ", [
      "bash ${local.create_script}",
      self.triggers.vm_name,
      var.vcpu,
      var.memory_mb,
      var.network_name,
      var.base_volume_name,
      var.pool_name,
      local_file.user_data.filename,
      length(local_file.network_config) > 0 ? local_file.network_config[0].filename : "-",
      var.pool_path,
      var.disk_gb == null ? "" : var.disk_gb,
    ])
  }

  provisioner "local-exec" {
    when    = destroy
    command = "bash ${self.triggers.delete_script} ${self.triggers.vm_name} ${self.triggers.pool_name}"
  }

  depends_on = [local_file.user_data]
}
