locals {
  all-instances = {
    for k, v in vultr_instance.instance : k => {
      public_ip  = v.main_ip
      private_ip = v.internal_ip
      region     = v.region
      dc         = local.instance-plan[k].dc
      type       = local.instance-plan[k].type
    }
  }
  by_dc = {
    for dc in distinct(values(local.all-instances)[*].dc) : dc => {
      for k, v in local.all-instances : k => v if v.dc == dc
    }
  }
  by_dc_type = {
    for dc, instances in local.by_dc : dc => {
      for type in distinct(values(instances)[*].type) : type => {
        for k, v in local.all-instances : k => v if v.type == type && v.dc == dc
      }
    }
  }
  by_type = {
    for type in distinct(values(local.all-instances)[*].type) : type => {
      for k, v in local.all-instances : k => v if v.type == type
    }
  }
  by_type_dc = {
    for type, instances in local.by_type : type => {
      for dc in distinct(values(instances)[*].dc) : dc => {
        for k, v in local.all-instances : k => v if v.dc == dc && v.type == type
      }
    }
  }
}

output "all-instances" {
  value = local.all-instances
}

output "by_dc" {
  value = {
    all     = local.by_dc
    by_type = local.by_dc_type
  }
}

output "by_type" {
  value = {
    all   = local.by_type
    by_dc = local.by_type_dc
  }
}