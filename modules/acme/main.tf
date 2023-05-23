variable "connection" {
  type = object({
    host        = string
    user        = optional(string, "root")
    port        = optional(number, 22)
    password    = optional(string)
    private_key = optional(string)
    agent       = optional(string)
  })
}
variable "email" {
  type = string
}
variable "domain" {
  type = string
}
variable "install_cert" {
  type = map(object({
    key_file       = string
    fullchain_file = string
    reloadcmd      = string
  }))
}

resource "null_resource" "acme" {
  connection {
    host        = var.connection.host
    user        = var.connection.user
    port        = var.connection.port
    password    = var.connection.password
    private_key = var.connection.private_key
    agent       = var.connection.agent
  }

  provisioner "remote-exec" {
    inline = [
      "curl https://get.acme.sh | sh -s email=${var.email}",
      ".acme.sh/acme.sh --issue -d ${var.domain} --standalone",
    ]
  }
}

resource "null_resource" "install-cert" {
  depends_on = [null_resource.acme]

  connection {
    host        = var.connection.host
    user        = var.connection.user
    port        = var.connection.port
    password    = var.connection.password
    private_key = var.connection.private_key
    agent       = var.connection.agent
  }

  for_each = var.install_cert

  provisioner "remote-exec" {
    inline = [
      <<EOF
.acme.sh/acme.sh --install-cert -d ${var.domain} \
  --key-file ${each.value.key_file} \
  --fullchain-file ${each.value.fullchain_file} \
  --reloadcmd "${each.value.reloadcmd}"
EOF
    ]
  }
}