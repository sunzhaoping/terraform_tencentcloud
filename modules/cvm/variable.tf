variable "ec2" {
  type    = map(any)
  default = {}
}

variable "zone_id" {}

variable "env_name" {}

variable "name" {}

variable "provision_sg_rules" {
  type = map(object({
    ip   = list(string)
    port = list(number)
  }))
}

variable "private_key" {
  description = "SSH private key"
  type        = string
  sensitive   = true
}