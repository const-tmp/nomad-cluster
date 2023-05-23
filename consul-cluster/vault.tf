resource "vault_pki_secret_backend_role" "consul-pki-role" {
  backend            = var.pki_intermediate_path
  name               = var.pki_role
  allow_localhost    = true
  allowed_domains    = ["${var.datacenter}.${var.domain}"]
  allow_subdomains   = true
  allow_glob_domains = false
  generate_lease     = true
  key_type           = "ec"
  key_bits           = 256
}

resource "vault_pki_secret_backend_cert" "server-tls" {
  for_each    = var.server_nodes
  backend     = vault_pki_secret_backend_role.consul-pki-role.backend
  name        = vault_pki_secret_backend_role.consul-pki-role.name
  common_name = "server.${var.datacenter}.${var.domain}"
  ip_sans     = ["127.0.0.1", each.value]
  alt_names   = ["localhost"]
  ttl         = "1h"
}

resource "vault_pki_secret_backend_cert" "client-tls" {
  backend     = vault_pki_secret_backend_role.consul-pki-role.backend
  name        = vault_pki_secret_backend_role.consul-pki-role.name
  common_name = "client.${var.datacenter}.${var.domain}"
  ttl         = "365d"
}

resource "vault_policy" "consul-pki" {
  name   = "consul-pki"
  policy = <<EOF
path "${var.pki_intermediate_path}/issue/${var.pki_role}" {
  capabilities = ["update"]
}
EOF
}

resource "vault_approle_auth_backend_role" "consul-tls-agent" {
  role_name              = "consul-tls-agent"
  token_explicit_max_ttl = 0
  token_policies         = [vault_policy.consul-pki.name]
}

