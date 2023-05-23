variable "approle" {
  type = string
}
variable "token_policies" {
  type = list(string)
}
variable "vault_addr" {
  type = string
}
variable "tls_skip_verify" {
  type = bool
}
variable "backend" {
  type = string
}
variable "acl_role" {
  type = string
}
variable "nodes" {
  type = map(string)
}

resource "vault_approle_auth_backend_role" "approle" {
  role_name              = var.approle
  token_policies         = var.token_policies
}

module "vault-agent" {
  source     = "../../modules/vault/agent"
  depends_on = [vault_approle_auth_backend_role.approle]
  for_each   = var.nodes
  connection = {
    host  = each.value
    agent = true
  }
  approle  = vault_approle_auth_backend_role.approle
  data_dir = "/etc/consul.d/vault-agent-acl"
  name     = "consul-acl"
  user     = "consul"
  config = {
    vault = {
      address         = var.vault_addr
      tls_skip_verify = var.tls_skip_verify
    }
    auto_auth = {
      method = [
        {
          type = "approle"
          config = {
            role_id_file_path                   = "/etc/consul.d/vault-agent-acl/roleid"
            secret_id_file_path                 = "/etc/consul.d/vault-agent-acl/secretid"
            remove_secret_id_file_after_reading = false
          }
        }
      ]
    }
    api_proxy = {
      use_auto_auth_token = true
    }
    listener = {
      unix = {
        address     = "/etc/consul.d/vault-agent-acl/vault.sock"
        socket_mode = "0600"
        tls_disable = true
      }
    }
    template = [
      {
        source      = "/etc/consul.d/vault-agent-acl/acl.json.tpl"
        destination = "/etc/consul.d/acl.json"
      },
    ]
  }
  templates = {
    "/etc/consul.d/vault-agent-acl/acl.json.tpl" = replace(jsonencode({
      acl = {
        enabled                  = true
        default_policy           = "deny"
        enable_token_persistence = true
        tokens = {
          default = "{{ with secret \"${var.backend}/creds/${var.acl_role}\" }}{{- .Data.token -}}{{ end }}"
        }
      }
    }), "\\\"", "\"")
  }
}
