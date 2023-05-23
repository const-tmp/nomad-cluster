resource "vault_consul_secret_backend" "backend" {
  address     = var.consul_addr
  scheme      = "https"
  description = "Bootstrap the Consul backend"
  ca_cert     = var.ca_cert
  client_cert = var.client_cert
  client_key  = var.client_key
  token       = var.consul_acl_token
}

resource "consul_acl_policy" "agent" {
  name  = "agent"
  rules = <<EOF
agent_prefix "" {
  policy = "write"
}
EOF
}

resource "consul_acl_role" "agent" {
  name     = consul_acl_policy.agent.name
  policies = [consul_acl_policy.agent.id]
}

resource "vault_consul_secret_backend_role" "vault" {
  name               = "vault"
  backend            = vault_consul_secret_backend.backend.path
  node_identities    = [for id, _ in var.vault_nodes : "${id}:${var.datacenter}"]
  service_identities = ["vault:${var.datacenter}"]
  consul_roles       = [consul_acl_role.agent.name]
  ttl                = var.acl_ttl
  max_ttl            = var.max_acl_ttl
}

resource "vault_policy" "vault" {
  name   = "consul-acl-${vault_consul_secret_backend_role.vault.name}"
  policy = <<EOP
path "consul/creds/${vault_consul_secret_backend_role.vault.name}" {
  capabilities = ["read"]
}
EOP
}

resource "consul_acl_policy" "nomad-server" {
  name  = "nomad-server"
  rules = <<EOF
agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

service_prefix "" {
  policy = "write"
}

acl = "write"
EOF
}

resource "consul_acl_role" "nomad-server" {
  name     = consul_acl_policy.nomad-server.name
  policies = [consul_acl_policy.nomad-server.id]
}

resource "vault_consul_secret_backend_role" "infra" {
  name               = "infra"
  backend            = vault_consul_secret_backend.backend.path
  node_identities    = [for id, _ in var.infra_nodes : "${id}:${var.datacenter}"]
  service_identities = [
    "consul:${var.datacenter}",
    "nomad:${var.datacenter}",
  ]
  consul_roles = [
    consul_acl_role.agent.name,
    consul_acl_role.nomad-server.name,
  ]
  ttl     = var.acl_ttl
  max_ttl = var.max_acl_ttl
}

resource "vault_policy" "infra" {
  name   = "consul-acl-${vault_consul_secret_backend_role.infra.name}"
  policy = <<EOP
path "consul/creds/${vault_consul_secret_backend_role.infra.name}" {
  capabilities = ["read"]
}
EOP
}

resource "consul_acl_policy" "nomad-client" {
  name  = "nomad-client"
  rules = <<EOF
agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

service_prefix "" {
  policy = "write"
}

# uncomment if using Consul KV with Consul Template
# key_prefix "" {
#   policy = "read"
# }
EOF
}

resource "consul_acl_role" "nomad-client" {
  name     = consul_acl_policy.nomad-client.name
  policies = [consul_acl_policy.nomad-client.id]
}

resource "vault_consul_secret_backend_role" "nomad-client" {
  name               = consul_acl_role.nomad-client.name
  backend            = vault_consul_secret_backend.backend.path
  node_identities    = [for id, _ in var.nomad_client_nodes : "${id}:${var.datacenter}"]
  service_identities = []
  consul_roles       = [
    consul_acl_role.agent.name,
    consul_acl_role.nomad-client.name,
  ]
  ttl     = var.acl_ttl
  max_ttl = var.max_acl_ttl
}

resource "vault_policy" "nomad-client" {
  name   = "consul-acl-${vault_consul_secret_backend_role.nomad-client.name}"
  policy = <<EOP
path "consul/creds/${vault_consul_secret_backend_role.nomad-client.name}" {
  capabilities = ["read"]
}
EOP
}

resource "consul_acl_policy" "patroni" {
  name  = "patroni"
  rules = <<EOF
service_prefix "${var.patroni_scope}" {
  policy = "write"
}
key_prefix "${var.patroni_namespace}/${var.patroni_scope}" {
    policy = "write"
}
session_prefix "" {
    policy = "write"
}
EOF
}

resource "consul_acl_role" "patroni" {
  name     = consul_acl_policy.patroni.name
  policies = [consul_acl_policy.patroni.id]
}

resource "vault_consul_secret_backend_role" "patroni" {
  name               = "patroni"
  backend            = vault_consul_secret_backend.backend.path
  node_identities    = [for id, _ in var.patroni_nodes : "${id}:${var.datacenter}"]
  service_identities = ["patroni:${var.datacenter}"]
  consul_roles       = [consul_acl_role.agent.name, consul_acl_role.patroni.name]
  ttl                = var.acl_ttl
  max_ttl            = var.max_acl_ttl
}

resource "vault_policy" "patroni" {
  name   = "consul-acl-${vault_consul_secret_backend_role.patroni.name}"
  policy = <<EOP
path "consul/creds/${vault_consul_secret_backend_role.patroni.name}" {
  capabilities = ["read"]
}
EOP
}

module "vault-agent-vault" {
  source          = "./vault-agent"
  acl_role        = vault_consul_secret_backend_role.vault.name
  backend         = vault_consul_secret_backend.backend.path
  nodes           = var.vault_nodes
  approle         = vault_policy.vault.name
  tls_skip_verify = false
  token_policies  = [vault_policy.vault.name]
  vault_addr      = var.vault_addr
}

module "vault-agent-infra" {
  source          = "./vault-agent"
  acl_role        = vault_consul_secret_backend_role.infra.name
  backend         = vault_consul_secret_backend.backend.path
  nodes           = var.infra_nodes
  approle         = vault_policy.infra.name
  tls_skip_verify = false
  token_policies  = [vault_policy.infra.name]
  vault_addr      = var.vault_addr
}

module "vault-agent-nomad-client" {
  source          = "./vault-agent"
  acl_role        = vault_consul_secret_backend_role.nomad-client.name
  backend         = vault_consul_secret_backend.backend.path
  nodes           = var.nomad_client_nodes
  approle         = vault_policy.nomad-client.name
  tls_skip_verify = false
  token_policies  = [vault_policy.nomad-client.name]
  vault_addr      = var.vault_addr
}

module "vault-agent-patroni" {
  source          = "./vault-agent"
  acl_role        = vault_consul_secret_backend_role.patroni.name
  backend         = vault_consul_secret_backend.backend.path
  nodes           = var.patroni_nodes
  approle         = vault_policy.patroni.name
  tls_skip_verify = false
  token_policies  = [vault_policy.patroni.name]
  vault_addr      = var.vault_addr
}
