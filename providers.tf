terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = ">= 2.12.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">= 1.19.0"
    }
  }
}

provider "vault" {
  address = var.vault_addr
}

provider "consul" {
  address  = module.consul-cluster.consul_addr
  ca_pem   = module.consul-cluster.ca
  cert_pem = module.consul-cluster.cert
  key_pem  = module.consul-cluster.key
  token    = module.consul-cluster.token
}

provider "nomad" {
  address  = module.nomad-cluster.nomad_addr
  ca_pem   = module.nomad-cluster.ca
  cert_pem = module.nomad-cluster.cert
  key_pem  = module.nomad-cluster.key
  token    = module.nomad-cluster.token
}

provider "postgresql" {
  host      = data.consul_service.postgres.service[0].address
  port      = data.consul_service.postgres.service[0].port
  database  = "postgres"
  username  = data.vault_generic_secret.root-creds.data.username
  password  = data.vault_generic_secret.root-creds.data.password
  superuser = true
  sslmode   = "require"
  #  expected_version = var.po
}