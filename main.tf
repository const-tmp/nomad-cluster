module "required-vault-config" {
  source                = "./required-vault-config"
  intermediate_pki_path = var.pki_intermediate_path
  root_pki_path         = var.pki_root_path
  vault_nodes           = values(var.vault_nodes)
}

module "vm" {
  source       = "./01-vm"
  domain       = var.domain
  email        = var.email
  os_id        = var.os_id
  ssh_key_name = var.ssh_key_name
}

module "consul-cluster" {
  source                = "./consul-cluster"
  depends_on            = [module.required-vault-config]
  client_nodes          = merge(var.vault_nodes, module.vm.nomad_client_nodes, module.vm.patroni_nodes)
  pki_ttl               = "1h"
  encrypt               = var.consul_encrypt
  pki_intermediate_path = var.pki_intermediate_path
  pki_role              = var.consul_pki_role
  server_nodes          = module.vm.consul_server_nodes
  vault_addr            = var.vault_addr
}

module "consul-acl" {
  source             = "./consul-acl"
  ca_cert            = module.consul-cluster.ca
  client_cert        = module.consul-cluster.cert
  client_key         = module.consul-cluster.key
  consul_acl_token   = module.consul-cluster.token
  consul_addr        = module.consul-cluster.consul_addr
  infra_nodes        = module.vm.consul_server_nodes
  nomad_client_nodes = module.vm.nomad_client_nodes
  patroni_nodes      = module.vm.patroni_nodes
  vault_addr         = var.vault_addr
  vault_nodes        = var.vault_nodes
  patroni_namespace  = var.patroni_namespace
  patroni_scope      = var.patroni_scope
}

module "nomad-cluster" {
  depends_on            = [module.consul-cluster, module.consul-acl]
  source                = "./nomad-cluster"
  client_nodes          = module.vm.nomad_client_nodes
  server_nodes          = module.vm.nomad_server_nodes
  datacenter            = var.nomad_dc
  region                = var.nomad_region
  pki_intermediate_path = var.pki_intermediate_path
  pki_role              = var.nomad_pki_role
  pki_ttl               = "1h"
  env_file              = var.nomad_env_file
  local_tls_dir         = var.tls_dir
  secret_dir            = var.secret_dir
  vault_addr            = var.vault_addr
}

module "patroni" {
  source        = "./patroni-cluster"
  depends_on    = [module.consul-cluster, module.consul-acl]
  patroni_nodes = module.vm.patroni_nodes
  namespace     = var.patroni_namespace
  scope         = var.patroni_scope
}
