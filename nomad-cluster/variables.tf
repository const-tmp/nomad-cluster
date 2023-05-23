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
  default = "/opt/nomad"
}
variable "tls_dir" {
  default = "/opt/nomad/tls"
}
variable "datacenter" {
  type = string
}
variable "pki_intermediate_path" {
  type = string
}
variable "pki_role" {
  type = string
}
variable "region" {
  type = string
}
variable "env_file" {
  type = string
}
variable "secret_dir" {
  type = string
}
variable "local_tls_dir" {
  type = string
}
variable "vault_addr" {
  type = string
}
variable "pki_ttl" {
  type = string
}
