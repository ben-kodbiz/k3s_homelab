output "network_name" {
  value = module.network.network_name
}

output "network_id" {
  value = module.network.network_id
}

output "gateway_ip" {
  value = local.gateway_ip
}

output "pool_name" {
  value = var.pool_name
}

output "cluster_a_nodes" {
  value       = var.cluster_a_enabled ? module.cluster_a[0].node_inventory : []
  description = "Deterministic node list (role, hostname, ip)"
}

output "cluster_a_api_vip" {
  value = var.cluster_a_enabled ? var.cluster_a_api_vip : null
}

output "cluster_b_nodes" {
  value = var.cluster_b_enabled ? module.cluster_b[0].node_inventory : []
}

output "cluster_b_api_vip" {
  value = var.cluster_b_enabled ? var.cluster_b_api_vip : null
}
