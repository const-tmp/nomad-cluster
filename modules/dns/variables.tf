variable "domain" {
  type = string
}
variable "certs" {
  type = map(object({
    install = map(object({
      key_file       = string
      fullchain_file = string
      reloadcmd      = string
    }))
    nodes = map(string)
  }))
}
variable "ttl" {
  default = 300
}
variable "priority" {
  default = -1
}
variable "email" {
  type = string
}
