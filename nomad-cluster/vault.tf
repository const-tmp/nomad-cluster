resource "vault_pki_secret_backend_role" "nomad-pki" {
  backend          = var.pki_intermediate_path
  name             = var.pki_role
  allowed_domains  = ["${var.region}.nomad"]
  allow_subdomains = true
  generate_lease   = true
}

resource "vault_policy" "nomad-pki" {
  name   = "nomad-pki"
  policy = <<EOF
path "${var.pki_intermediate_path}/issue/${vault_pki_secret_backend_role.nomad-pki.name}" {
  capabilities = ["update"]
}
EOF
}

resource "vault_approle_auth_backend_role" "nomad-pki" {
  role_name      = "nomad-pki"
  token_policies = [vault_policy.nomad-pki.name]
}

resource "vault_pki_secret_backend_cert" "server" {
  for_each    = var.server_nodes
  backend     = vault_pki_secret_backend_role.nomad-pki.backend
  name        = vault_pki_secret_backend_role.nomad-pki.name
  common_name = "server.${var.region}.nomad"
  ip_sans     = ["127.0.0.1", each.value]
  alt_names   = ["localhost"]
  ttl         = "1h"
}

resource "vault_pki_secret_backend_cert" "client" {
  for_each    = var.client_nodes
  backend     = vault_pki_secret_backend_role.nomad-pki.backend
  name        = vault_pki_secret_backend_role.nomad-pki.name
  common_name = "client.${var.region}.nomad"
  ip_sans     = ["127.0.0.1", each.value]
  alt_names   = ["localhost"]
  ttl         = "1h"
}

resource "vault_pki_secret_backend_cert" "cli" {
  backend     = vault_pki_secret_backend_role.nomad-pki.backend
  name        = vault_pki_secret_backend_role.nomad-pki.name
  common_name = "cli.${var.region}.nomad"
  ttl         = "365d"
}

resource "vault_nomad_secret_backend" "backend" {
  address     = "https://${values(var.server_nodes)[0]}:4646"
  ca_cert     = vault_pki_secret_backend_cert.cli.issuing_ca
  client_cert = vault_pki_secret_backend_cert.cli.certificate
  client_key  = vault_pki_secret_backend_cert.cli.private_key
  token       = jsondecode(data.local_sensitive_file.bootstrap.content).SecretID
  description = "Nomad ACL"
}

resource "vault_policy" "nomad-server" {
  name   = "nomad-server"
  policy = <<EOF
# Allow creating tokens under "nomad-cluster" token role. The token role name
# should be updated if "nomad-cluster" is not used.
path "auth/token/create/nomad-cluster" {
  capabilities = ["update"]
}

# Allow looking up "nomad-cluster" token role. The token role name should be
# updated if "nomad-cluster" is not used.
path "auth/token/roles/nomad-cluster" {
  capabilities = ["read"]
}

# Allow looking up the token passed to Nomad to validate # the token has the
# proper capabilities. This is provided by the "default" policy.
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Allow looking up incoming tokens to validate they have permissions to access
# the tokens they are requesting. This is only required if
# `allow_unauthenticated` is set to false.
path "auth/token/lookup" {
  capabilities = ["update"]
}

# Allow revoking tokens that should no longer exist. This allows revoking
# tokens for dead tasks.
path "auth/token/revoke-accessor" {
  capabilities = ["update"]
}

# Allow checking the capabilities of our own token. This is used to validate the
# token upon startup.
path "sys/capabilities-self" {
  capabilities = ["update"]
}

# Allow our own token to be renewed.
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF
}

resource "vault_token_auth_backend_role" "nomad-cluster" {
  role_name              = "nomad-cluster"
  disallowed_policies    = [vault_policy.nomad-server.name]
  token_explicit_max_ttl = 0
  orphan                 = true
  token_period           = 60 * 60
  renewable              = true
}

resource "vault_token" "nomad-server-token" {
  policies  = [vault_policy.nomad-server.name]
  no_parent = true
  period    = "1h"
}
