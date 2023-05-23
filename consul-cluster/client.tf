resource "null_resource" "consul-client" {
  for_each = var.client_nodes

  connection {
    host  = each.value
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's|ConditionFileNotEmpty=/etc/consul.d/consul.hcl|ConditionFileNotEmpty=/etc/consul.d/config.json|' /lib/systemd/system/consul.service",
      "rm -f /etc/consul.d/consul.hcl",
      "mkdir -p ${var.tls_dir}",
    ]
  }

  provisioner "file" {
    content = jsonencode({
      data_dir            = var.data_dir
      datacenter          = var.datacenter
      domain              = var.domain
      node_name           = each.key
      encrypt             = var.encrypt
      log_level           = var.log_level
      advertise_addr      = each.value
      advertise_addr_wan  = each.value
      translate_wan_addrs = var.translate_wan_addrs
      auto_reload_config  = var.auto_reload_config
      auto_encrypt = {
        tls = true
      }
      ports = {
        grpc     = 8502
        grpc_tls = 8503
      }
      retry_join = values(var.server_nodes)
    })
    destination = "/etc/consul.d/config.json"
  }

  provisioner "file" {
    content = jsonencode({
      acl = {
        enabled                  = true
        default_policy           = "allow"
        enable_token_persistence = true
      }
    })
    destination = "/etc/consul.d/acl.json"
  }

  provisioner "file" {
    content = jsonencode({
      tls = {
        defaults = {
          ca_file         = "${var.tls_dir}/ca.pem"
          verify_incoming = true
          verify_outgoing = true
        }
        internal_rpc = {
          verify_server_hostname = true
        }
      }
    })
    destination = "/etc/consul.d/tls.json"
  }

  provisioner "file" {
    content     = values(vault_pki_secret_backend_cert.server-tls)[0].issuing_ca
    destination = "${var.tls_dir}/ca.pem"
  }

  provisioner "file" {
    content = jsonencode({
      connect = {
        enabled = true
      }
    })
    destination = "/etc/consul.d/connect.json"
  }

  provisioner "remote-exec" {
    inline = [
      "chown -R consul:consul /etc/consul.d ${var.tls_dir}",
      "systemctl daemon-reload",
      "systemctl enable consul.service",
      "systemctl restart consul.service",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      <<EOF
echo "Waiting for Consul start"
while ! curl --output /dev/null --silent --fail  http://localhost:8500; do
  sleep 5s
done
echo "Consul started"
EOF
    ]
  }
}

module "consul-client-pki-agent" {
  source     = "../modules/vault/agent"
  depends_on = [
    vault_approle_auth_backend_role.consul-tls-agent,
    null_resource.consul-client,
  ]
  for_each   = var.client_nodes
  approle    = vault_approle_auth_backend_role.consul-tls-agent
  connection = {
    host  = each.value
    agent = true
  }
  config = {
    vault = {
      address         = var.vault_addr
      tls_skip_verify = false
    }
    auto_auth = {
      method = [
        {
          type = "approle"
          config = {
            role_id_file_path                   = "${local.consul-pki-dir}/roleid"
            secret_id_file_path                 = "${local.consul-pki-dir}/secretid"
            remove_secret_id_file_after_reading = false
          }
        }
      ]
      sinks = [
        {
          sink = {
            type = "file"
            config = {
              path = "${local.consul-pki-dir}/vault_token"
            }
          }
        }
      ]
    }
    api_proxy = {
      use_auto_auth_token = true
    }
    listener = {
      unix = {
        address     = "${local.consul-pki-dir}/vault.sock"
        socket_mode = "0600"
        tls_disable = true
      }
    }
    template = [
      {
        source      = "${local.consul-pki-dir}/ca.crt.tpl"
        destination = "${var.tls_dir}/ca.pem"
        exec = {
          command = ["consul", "reload"]
        }
      },
    ]
  }
  data_dir = local.consul-pki-dir
  name     = "consul-tls"
  templates = {
    "${local.consul-pki-dir}/ca.crt.tpl" = <<EOF
{{ with secret "${var.pki_intermediate_path}/issue/${var.pki_role}" "common_name=server.${var.datacenter}.${var.domain}" "ttl=${var.pki_ttl}" }}
{{ .Data.issuing_ca }}
{{ end }}
EOF
  }
  user = "consul"
}
