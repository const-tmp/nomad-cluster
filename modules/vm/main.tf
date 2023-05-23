data "vultr_ssh_key" "ssh_key" {
  filter {
    name   = "name"
    values = [var.ssh_key_name]
  }
}

data "cloudinit_config" "cloud-init" {
  for_each = var.cloud_config

  gzip          = false
  base64_encode = false

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content      = yamlencode(each.value)
  }
}

resource "vultr_vpc" "vpc" {
  for_each = var.instances
  region   = each.value.region
}

locals {
  instance-plan = merge([
    for dc_name, dc in var.instances : merge([
      for type, data in dc.instances : {
        for i in range(data.count) : "${type}-${dc_name}-${i + 1}" => {
          dc     = dc_name
          region = dc.region
          type   = type
          plan   = data.plan != null ? data.plan : var.default_plan
          vpc_id = can(vultr_vpc.vpc[dc_name]) ? [vultr_vpc.vpc[dc_name].id] : []
        }
      }
    ]...)
  ]...)
}

resource "vultr_instance" "instance" {
  for_each         = local.instance-plan
  plan             = each.value.plan
  region           = each.value.region
  os_id            = var.os_id
  label            = each.key
  hostname         = each.key
  user_data        = can(data.cloudinit_config.cloud-init[each.value.type]) ? data.cloudinit_config.cloud-init[each.value.type].rendered : null
  ssh_key_ids      = [data.vultr_ssh_key.ssh_key.id]
  vpc_ids          = each.value.vpc_id
  enable_ipv6      = false
  ddos_protection  = false
  activation_email = false
  backups          = "disabled"
  #  backups          = "enabled"
  #  backups_schedule {
  #    type = "daily"
  #  }
}
