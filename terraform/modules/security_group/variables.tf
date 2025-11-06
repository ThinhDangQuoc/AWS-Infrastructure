variable "vpc_id" {
  type = string
}

variable "allowed_ssh_cidr" {
  type = string
}

variable "allowed_from_port" {
  type    = number
  default = 22
}

variable "allowed_to_port" {
  type    = number
  default = 22
}

variable "allowed_protocol" {
  type    = string
  default = "tcp"
}