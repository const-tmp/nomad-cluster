# VM
variable "os_id" {
  type = number
}
variable "ssh_key_name" {
  type = string
}

# DNS
variable "domain" {
  type = string
}
variable "email" {
  type = string
}
variable "ttl" {
  default = 300
}
variable "priority" {
  default = -1
}
