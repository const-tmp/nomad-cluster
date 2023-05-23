variable "vault_addr" {
  type = string
}
variable "consul_addr" {
  type = string
}
variable "datacenter" {
  default = "dc1"
}
variable "ca_cert" {
  type = string
}
variable "client_cert" {
  type = string
}
variable "client_key" {
  type      = string
  sensitive = true
}
variable "consul_acl_token" {
  type      = string
  sensitive = true
}
variable "max_acl_ttl" {
  default = 60 * 60 * 24
}
variable "acl_ttl" {
  default = 60 * 60
}
variable "vault_nodes" {
  type = map(string)
}
variable "infra_nodes" {
  type = map(string)
}
variable "nomad_client_nodes" {
  type = map(string)
}
variable "patroni_nodes" {
  type = map(string)
}
variable "patroni_scope" {
  type = string
}
variable "patroni_namespace" {
  type = string
}
