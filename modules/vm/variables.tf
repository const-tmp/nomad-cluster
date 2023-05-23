variable "instances" {
  type = map(object({
    region = string
    instances = map(object({
      plan  = optional(string)
      count = number
    }))
  }))
}
variable "default_plan" {
  type    = string
  default = "vc2-1c-1gb"
}
variable "ssh_key_name" {
  type = string
}
variable "os_id" {
  type = number
}
variable "cloud_config" {
  type = any
}
