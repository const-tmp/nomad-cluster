data "vultr_dns_domain" "domain" {
  domain = var.domain
}

resource "vultr_dns_record" "A" {
  for_each = merge([
    for name, data in var.certs : {
      for subdomain, ip in data.nodes : subdomain => ip
    }
  ]...)
  data     = each.value
  domain   = data.vultr_dns_domain.domain.domain
  name     = each.key
  type     = "A"
  ttl      = var.ttl
  priority = var.priority
}

resource "null_resource" "acme" {
  depends_on = [vultr_dns_record.A]

  for_each = merge([for name, data in var.certs : data.nodes]...)

  connection {
    host  = each.value
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "curl https://get.acme.sh | sh -s email=${var.email}",
      ".acme.sh/acme.sh --issue -d ${each.key}.${var.domain} --standalone",
    ]
  }
}

resource "null_resource" "install-cert" {
  depends_on = [null_resource.acme]

  for_each = mergre([
    for type, certs in var.certs : merge([
      for subdomain, ip in certs.nodes : {
        for name, install in certs.install : "${type}-${subdomain}-${name}" => {
          ip             = ip
          subdomain      = subdomain
          key_file       = install.key_file
          fullchain_file = install.fullchain_file
          reloadcmd      = install.reloadcmd
        }
      }
    ]...)
  ]...)

  connection {
    host  = each.value.ip
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      <<EOF
.acme.sh/acme.sh --install-cert -d ${each.value.subdomain}.${var.domain} \
  --key-file ${each.value.key_file} \
  --fullchain-file ${each.value.fullchain_file} \
  --reloadcmd "${each.value.reloadcmd}"
EOF
    ]
  }
}
