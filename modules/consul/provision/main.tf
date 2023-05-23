module "server-config" {
  source              = "./server/config"
  for_each            = var.server_nodes
  advertise_addr      = each.value
  advertise_addr_wan  = each.value
  auto_reload_config  = var.auto_reload_config
  bootstrap_expect    = length(var.server_nodes)
  data_dir            = var.data_dir
  datacenter          = var.datacenter
  domain              = var.domain
  encrypt             = var.encrypt
  node_name           = each.key
  retry_join          = [for ip in var.server_nodes : ip if ip != each.value]
  retry_join_wan      = []
  translate_wan_addrs = var.translate_wan_addrs
  log_level           = var.log_level
}

resource "null_resource" "consul" {
  triggers = { for k, v in module.server-config : k => v.json }

  for_each = var.server_nodes

  connection {
    host  = each.value
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's|ConditionFileNotEmpty=/etc/consul.d/consul.hcl|ConditionFileNotEmpty=/etc/consul.d/config.json|' /lib/systemd/system/consul.service",
      "rm -f /etc/consul.d/consul.hcl",
    ]
  }

  provisioner "file" {
    content     = module.server-config[each.key].json
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

  provisioner "remote-exec" {
    inline = [
      "chown -R consul:consul /etc/consul.d",
      "systemctl daemon-reload",
      "systemctl enable consul.service",
    ]
  }
}

resource "null_resource" "consul-client" {
  triggers = {
    config = jsonencode({
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
        grpc_tls = 8502
      }
      retry_join = values(var.server_nodes)
    })
  }

  for_each = var.client_nodes

  connection {
    host  = each.value
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's|ConditionFileNotEmpty=/etc/consul.d/consul.hcl|ConditionFileNotEmpty=/etc/consul.d/config.json|' /lib/systemd/system/consul.service",
      "rm -f /etc/consul.d/consul.hcl",
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

  provisioner "remote-exec" {
    inline = [
      "chown -R consul:consul /etc/consul.d",
      "systemctl daemon-reload",
      "systemctl enable consul.service",
    ]
  }
}

module "consul-dns-forwarding" {
  source   = "../dns-forwarding"
  for_each = merge(var.client_nodes, var.server_nodes)
  connection = {
    host  = each.value
    agent = true
  }
}
