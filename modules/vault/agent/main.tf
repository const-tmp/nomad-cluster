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
variable "data_dir" {
  type = string
}
variable "user" {
  type = string
}
variable "name" {
  type = string
}
variable "approle" {
  type = object({
    role_name = string
    role_id   = string
  })
}
variable "config" {
  type = any
}
variable "templates" {
  type = map(string)
}

resource "vault_approle_auth_backend_role_secret_id" "approle" {
  role_name = var.approle.role_name
}

resource "null_resource" "templates" {
  for_each = var.templates

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
      "mkdir -p $(dirname ${each.key})",
    ]
  }

  provisioner "file" {
    content     = each.value
    destination = each.key
  }
}

resource "null_resource" "agent" {
  depends_on = [
    vault_approle_auth_backend_role_secret_id.approle,
    null_resource.templates,
  ]

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
      "id ${var.user} || useradd -Ms /bin/false ${var.user}",
      "mkdir -p ${var.data_dir}",
      "touch ${var.data_dir}/agent.json",
      "chown -R ${var.user}:${var.user} ${var.data_dir}",
    ]
  }

  provisioner "file" {
    content = templatefile("${path.module}/../../../configs/vault/agent/vault-agent.service", {
      user     = var.user
      group    = var.user
      data_dir = var.data_dir
      name     = var.name
    })
    destination = "/etc/systemd/system/vault-agent-${var.name}.service"
  }

  provisioner "file" {
    content     = jsonencode(var.config)
    destination = "${var.data_dir}/agent.json"
  }

  provisioner "file" {
    content     = var.approle.role_id
    destination = "${var.data_dir}/roleid"
  }

  provisioner "file" {
    content     = vault_approle_auth_backend_role_secret_id.approle.secret_id
    destination = "${var.data_dir}/secretid"
  }

  provisioner "remote-exec" {
    inline = [
      "systemctl daemon-reload",
      "systemctl enable vault-agent-${var.name}.service",
      "systemctl restart vault-agent-${var.name}.service",
    ]
  }
}
