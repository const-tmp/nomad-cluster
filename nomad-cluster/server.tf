resource "null_resource" "nomad" {
  for_each = var.server_nodes

  connection {
    host  = each.value
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "rm -f /etc/nomad.d/nomad.hcl",
      "mkdir -p ${var.tls_dir}"
    ]
  }

  provisioner "file" {
    content = jsonencode({
      datacenter = var.datacenter
      data_dir   = var.data_dir
      server     = {
        enabled          = true
        bootstrap_expect = length(var.server_nodes)
      }
      advertise = {
        http = each.value
        rpc  = each.value
        serf = each.value
      }
      tls = {
        http                   = true
        rpc                    = true
        ca_file                = "${var.tls_dir}/ca.pem"
        cert_file              = "${var.tls_dir}/cert.pem"
        key_file               = "${var.tls_dir}/key.pem"
        verify_server_hostname = true
        verify_https_client    = true
      }
      acl = {
        enabled = true
      }
    })
    destination = "/etc/nomad.d/config.json"
  }

  provisioner "file" {
    content     = vault_pki_secret_backend_cert.server[each.key].issuing_ca
    destination = "${var.tls_dir}/ca.pem"
  }

  provisioner "file" {
    content     = vault_pki_secret_backend_cert.server[each.key].certificate
    destination = "${var.tls_dir}/cert.pem"
  }

  provisioner "file" {
    content     = vault_pki_secret_backend_cert.server[each.key].private_key
    destination = "${var.tls_dir}/key.pem"
  }

  provisioner "file" {
    content     = jsonencode({
      vault = {
        enabled          = true
        address          = var.vault_addr
        tls_skip_verify  = false
        task_token_ttl   = "1h"
        create_from_role = vault_token_auth_backend_role.nomad-cluster.role_name
        token            = vault_token.nomad-server-token.client_token
      }
    })
    destination = "/etc/nomad.d/vault.json"
  }

  provisioner "remote-exec" {
    inline = [
      "chown -R nomad:nomad /etc/nomad.d ${var.tls_dir}",
      "chmod 600 ${var.tls_dir}/key.pem /etc/nomad.d/vault.json",
      "systemctl daemon-reload",
      "systemctl enable nomad.service",
      "systemctl restart nomad.service",
    ]
  }
}

locals {
  tls-agent-dir = "/etc/nomad.d/tls-agent"
}

module "server-tls-agent" {
  source     = "../modules/vault/agent"
  depends_on = [vault_approle_auth_backend_role.nomad-pki, null_resource.nomad]
  for_each   = var.server_nodes
  approle    = vault_approle_auth_backend_role.nomad-pki
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
          type   = "approle"
          config = {
            role_id_file_path                   = "${local.tls-agent-dir}/roleid"
            secret_id_file_path                 = "${local.tls-agent-dir}/secretid"
            remove_secret_id_file_after_reading = false
          }
        }
      ]
#      sinks = [
#        {
#          sink = {
#            type   = "file"
#            config = {
#              path = "${local.tls-agent-dir}/vault_token"
#            }
#          }
#        }
#      ]
    }
    api_proxy = {
      use_auto_auth_token = true
    }
    listener = {
      unix = {
        address     = "${local.tls-agent-dir}/vault.sock"
        socket_mode = "0600"
        tls_disable = true
      }
    }
    template = [
      {
        source      = "${local.tls-agent-dir}/ca.crt.tpl"
        destination = "${var.tls_dir}/ca.pem"
        exec        = {
          command = ["systemctl", "reload", "nomad.service"]
        }
      },
      {
        source      = "${local.tls-agent-dir}/agent.crt.tpl"
        destination = "${var.tls_dir}/cert.pem"
        exec        = {
          command = ["systemctl", "reload", "nomad.service"]
        }
      },
      {
        source      = "${local.tls-agent-dir}/agent.key.tpl"
        destination = "${var.tls_dir}/key.pem"
        exec        = {
          command = ["systemctl", "reload", "nomad.service"]
        }
        perms = "0600"
      },
    ]
  }
  data_dir  = local.tls-agent-dir
  name      = "nomad-tls"
  templates = {
    "${local.tls-agent-dir}/ca.crt.tpl"    = <<EOF
{{ with secret "${var.pki_intermediate_path}/issue/${var.pki_role}" "common_name=server.${var.region}.nomad" "ttl=${var.pki_ttl}" }}
{{ .Data.issuing_ca }}
{{ end }}
EOF
    "${local.tls-agent-dir}/agent.crt.tpl" = <<EOF
{{ with secret "${var.pki_intermediate_path}/issue/${var.pki_role}" "common_name=server.${var.region}.nomad" "ttl=${var.pki_ttl}" "alt_names=localhost" "ip_sans=127.0.0.1,${each.value}" }}
{{ .Data.certificate }}
{{ end }}
EOF
    "${local.tls-agent-dir}/agent.key.tpl" = <<EOF
{{ with secret "${var.pki_intermediate_path}/issue/${var.pki_role}" "common_name=server.${var.region}.nomad" "ttl=${var.pki_ttl}" "alt_names=localhost" "ip_sans=127.0.0.1,${each.value}" }}
{{ .Data.private_key }}
{{ end }}
EOF
  }
  user = "root"
}
