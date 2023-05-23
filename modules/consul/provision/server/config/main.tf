variable "data_dir" {
  type = string
}
variable "domain" {
  type = string
}
variable "node_name" {
  type = string
}
variable "encrypt" {
  type      = string
  sensitive = true
}
variable "translate_wan_addrs" {
  type = bool
}
variable "auto_reload_config" {
  type = bool
}
variable "datacenter" {
  type = string
}
variable "advertise_addr" {
  type = string
}
variable "advertise_addr_wan" {
  type = string
}
variable "bootstrap_expect" {
  type = number
}
variable "retry_join" {
  type = list(string)
}
variable "retry_join_wan" {
  type = list(string)
}
variable "log_level" {
  default = "INFO"
}

locals {
  config = {
    data_dir            = var.data_dir
    datacenter          = var.datacenter
    domain              = var.domain
    node_name           = var.node_name
    encrypt             = var.encrypt
    server              = true
    log_level           = var.log_level
    advertise_addr      = var.advertise_addr
    advertise_addr_wan  = var.advertise_addr_wan
    translate_wan_addrs = var.translate_wan_addrs
    bootstrap_expect    = var.bootstrap_expect
    client_addr         = "0.0.0.0"
    auto_reload_config  = var.auto_reload_config
    auto_encrypt = {
      allow_tls = true
    }
    performance = {
      raft_multiplier = 1
    }
    addresses = {
      grpc = "127.0.0.1"
      http = "127.0.0.1"
      dns  = "127.0.0.1"
    }
    ports = {
      https    = 8501
      grpc     = 8502
      grpc_tls = 8503
    }
    ui_config = {
      enabled = true
    }
    retry_join     = var.retry_join
    retry_join_wan = var.retry_join_wan
  }
}

output "json" {
  value = jsonencode(local.config)
}