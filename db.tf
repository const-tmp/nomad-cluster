data "consul_service" "postgres" {
  depends_on = [module.patroni]
  name       = "postgres"
  tag        = "master"

  lifecycle {
    postcondition {
      condition     = length(self.service)>0
      error_message = "No healthy postgres services"
    }
  }
}

resource "vault_mount" "db" {
  path = "db"
  type = "database"
}

resource "vault_database_secret_backend_connection" "root" {
  backend           = vault_mount.db.path
  name              = "postgres"
  allowed_roles     = ["root"]
  verify_connection = true

  postgresql {
    username       = "postgres"
    password       = "postgres-pass"
    connection_url = "postgresql://{{username}}:{{password}}@${data.consul_service.postgres.service[0].address}:${data.consul_service.postgres.service[0].port}/postgres"
  }
}

resource "vault_generic_endpoint" "rotate-root" {
  data_json      = "{}"
  path           = "${vault_mount.db.path}/rotate-root/${vault_database_secret_backend_connection.root.name}"
  disable_read   = true
  disable_delete = true
}

resource "vault_database_secret_backend_static_role" "root" {
  backend         = vault_database_secret_backend_connection.root.backend
  db_name         = vault_database_secret_backend_connection.root.name
  name            = "root"
  rotation_period = 60*60
  username        = vault_database_secret_backend_connection.root.postgresql[0].username
}

data "vault_generic_secret" "root-creds" {
  path = "${vault_database_secret_backend_static_role.root.backend}/static-creds/${vault_database_secret_backend_static_role.root.name}"
}

resource "postgresql_role" "owner" {
  for_each = var.databases
  name     = "${each.key}-owner"
}

resource "postgresql_role" "write" {
  for_each = var.databases
  name     = each.key
}

resource "postgresql_role" "read" {
  for_each = var.databases
  name     = "${each.key}-read"
}

resource "postgresql_database" "db" {
  for_each = var.databases
  name     = each.key
  owner    = postgresql_role.owner[each.key].name
}

resource "vault_database_secret_backend_connection" "db" {
  for_each      = var.databases
  backend       = vault_mount.db.path
  name          = each.key
  allowed_roles = [
    "${each.key}-owner",
    each.key,
    "${each.key}-read",
  ]
  verify_connection = true

  postgresql {
    username       = data.vault_generic_secret.root-creds.data.username
    password       = data.vault_generic_secret.root-creds.data.password
    connection_url = "postgresql://{{username}}:{{password}}@${data.consul_service.postgres.service[0].address}:${data.consul_service.postgres.service[0].port}/${postgresql_database.db[each.key].name}"
  }
}

resource "vault_database_secret_backend_role" "owner" {
  for_each            = var.databases
  backend             = vault_database_secret_backend_connection.db[each.key].backend
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' IN ROLE \"${postgresql_role.owner[each.key].name}\";",
  ]
  db_name     = vault_database_secret_backend_connection.db[each.key].name
  name        = postgresql_role.owner[each.key].name
  default_ttl = var.db_default_ttl
  max_ttl     = var.db_max_ttl
}

resource "vault_database_secret_backend_role" "write" {
  for_each            = var.databases
  backend             = vault_database_secret_backend_connection.db[each.key].backend
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT, UPDATE, DELETE, INSERT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
  ]
  db_name     = vault_database_secret_backend_connection.db[each.key].name
  name        = postgresql_role.write[each.key].name
  default_ttl = var.db_default_ttl
  max_ttl     = var.db_max_ttl
}

resource "vault_database_secret_backend_role" "read" {
  for_each            = var.databases
  backend             = vault_database_secret_backend_connection.db[each.key].backend
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
  ]
  db_name     = vault_database_secret_backend_connection.db[each.key].name
  name        = postgresql_role.read[each.key].name
  default_ttl = var.db_default_ttl
  max_ttl     = var.db_max_ttl
}
