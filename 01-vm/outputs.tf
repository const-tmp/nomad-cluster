output "nodes" {
  value = module.vm.by_type.all
}

locals {
  patroni-nodes = { for k, v in module.vm.by_type.all["patroni"] : k => v.public_ip }
  nomad-client-nodes = { for k, v in module.vm.by_type.all["nomad-client"] : k => v.public_ip }
}

output "consul_client_nodes" {
  value = merge(
    local.nomad-client-nodes,
    local.patroni-nodes,
  )
}

output "consul_server_nodes" {
  value = { for k, v in module.vm.by_type.all["infra"] : k => v.public_ip }
}

output "nomad_server_nodes" {
  value = { for k, v in module.vm.by_type.all["infra"] : k => v.public_ip }
}

output "nomad_client_nodes" {
  value = local.nomad-client-nodes
}

output "patroni_nodes" {
  value = local.patroni-nodes
}
