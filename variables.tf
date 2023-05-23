# Server
variable "os_id" {
  type = number
}
variable "ssh_key_name" {
  type = string
}

# ACME
variable "domain" {
  type = string
}
variable "email" {
  type = string
}

# Vault
variable "vault_addr" {
  type = string
}
variable "vault_nodes" {
  type = map(string)
}
variable "vault_tls_skip_verify" {
  type    = bool
  default = false
}
variable "pki_root_path" {
  type    = string
  default = "pki-root"
}
variable "pki_intermediate_path" {
  type    = string
  default = "pki"
}
variable "vault_env_file" {
  default = "vault.env"
}
variable "vault_init_file" {
  default = "vault-init.json"
}

# Consul
variable "consul_encrypt" {
  type = string
}
variable "consul_pki_role" {
  type    = string
  default = "consul"
}
variable "consul_dc" {
  default = "dc1"
}
variable "consul_domain" {
  type    = string
  default = "consul"
}
variable "consul_env_file" {
  default = "consul.env"
}

# Nomad
variable "nomad_pki_role" {
  type    = string
  default = "nomad"
}
variable "nomad_region" {
  default = "global"
}
variable "nomad_dc" {
  default = "dc1"
}
variable "nomad_env_file" {
  default = "nomad.env"
}

# DB
variable "patroni_scope" {
  default = "postgres"
}
variable "patroni_namespace" {
  default = "/"
}
variable "db_max_ttl" {
  default = 60*60*24
}
variable "db_default_ttl" {
  default = 60*60
}
variable "databases" {
  type = set(string)
}

# General
variable "secret_dir" {
  default = "secret"
}
variable "tls_dir" {
  default = "tls"
}
