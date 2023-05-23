variable "root_pki_path" {
  type = string
}
variable "intermediate_pki_path" {
  type = string
}
variable "vault_nodes" {
  type = list(string)
}

locals {
  minute = 60
  hour   = local.minute*60
  day    = local.hour*24
  month  = local.day*30
  year   = local.day*365
}

resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_mount" "root-pki" {
  path                  = var.root_pki_path
  type                  = "pki"
  max_lease_ttl_seconds = local.year*10
}

resource "vault_pki_secret_backend_root_cert" "root-ca" {
  backend              = vault_mount.root-pki.path
  common_name          = "Vault Root CA"
  type                 = "internal"
  ttl                  = local.year*10
  key_type             = "ec"
  key_bits             = 256
  exclude_cn_from_sans = true
}

resource "vault_pki_secret_backend_config_urls" "root-url-config" {
  backend                 = vault_mount.root-pki.path
  issuing_certificates    = formatlist("https://%s:8200/v1/%s/ca", var.vault_nodes, vault_mount.root-pki.path)
  crl_distribution_points = formatlist("https://%s:8200/v1/%s/crl", var.vault_nodes, vault_mount.root-pki.path)
}

resource "vault_mount" "intermediate-pki" {
  path                  = var.intermediate_pki_path
  type                  = "pki"
  max_lease_ttl_seconds = local.year*5
}

resource "vault_pki_secret_backend_intermediate_cert_request" "intermediate-csr" {
  backend              = vault_mount.intermediate-pki.path
  common_name          = "Vault Intermediate CA"
  type                 = "internal"
  key_type             = "ec"
  key_bits             = 256
  exclude_cn_from_sans = true
}

resource "vault_pki_secret_backend_root_sign_intermediate" "root-sign-intermediate" {
  backend     = vault_mount.root-pki.path
  common_name = vault_pki_secret_backend_intermediate_cert_request.intermediate-csr.common_name
  csr         = vault_pki_secret_backend_intermediate_cert_request.intermediate-csr.csr
  ttl         = vault_mount.intermediate-pki.max_lease_ttl_seconds
}

resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate-set-signed" {
  backend     = vault_mount.intermediate-pki.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.root-sign-intermediate.certificate
}

resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv"
  options     = { version = "1" }
  description = "KV Version 1 secret engine mount"
}

output "root_pki" {
  value = vault_mount.root-pki
}

output "intermediate_pki" {
  value = vault_mount.intermediate-pki
}
