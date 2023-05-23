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

module "consul-dns-forwarding" {
  source  = "nullc4t/template-sync/null"
  version = ">= 0.3.0"

  connection = var.connection
  exec_before = [
    "mkdir -p /etc/systemd/resolved.conf.d/",
  ]
  templates = {
    "/etc/systemd/resolved.conf.d/consul.conf" = file("${path.module}/../../../configs/consul/dns-forwarding.conf")
  }
  exec_after = [
    "systemctl restart systemd-resolved",
  ]
}
