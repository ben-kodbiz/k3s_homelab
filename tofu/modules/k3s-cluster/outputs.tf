output "control_plane" {
  value = {
    for h, m in module.control_plane : h => {
      ip   = m.static_ip
      name = m.domain_name
    }
  }
}

output "workers" {
  value = {
    for h, m in module.worker : h => {
      ip   = m.static_ip
      name = m.domain_name
    }
  }
}

output "api_vip" {
  value = var.api_vip
}

output "node_inventory" {
  value = concat(
    [for n in local.cp_nodes : { role = "server", hostname = n.hostname, ip = n.ip }],
    [for n in local.worker_nodes : { role = "agent", hostname = n.hostname, ip = n.ip }]
  )
}
