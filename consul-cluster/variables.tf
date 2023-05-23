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
variable "pki_intermediate_path" {
  type = string
}
variable "pki_role" {
  type = string
}
variable "tls_dir" {
  default = "/opt/consul/tls"
}
variable "local_tls_dir" {
  default = "tls"
}
variable "env_file" {
  default = "consul.env"
}
variable "secret_dir" {
  default = "secret"
}
variable "vault_addr" {
  type = string
}
variable "pki_ttl" {
  type = string
}
