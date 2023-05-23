variable "log_level" {
  type    = string
  default = "INFO"
}
variable "server_nodes" {
  type = map(string)
}
variable "client_nodes" {
  type = map(string)
}
variable "data_dir" {
  default = "/opt/consul"
}
variable "domain" {
  default = "consul"
}
variable "datacenter" {
  default = "dc1"
}
variable "encrypt" {
  type      = string
  sensitive = true
}
variable "translate_wan_addrs" {
  default = true
}
variable "auto_reload_config" {
  default = true
}
