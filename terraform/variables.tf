variable "aws_region" {
  type    = string
}


variable "instance_type" {
  type    = string
}



variable "vpc_cidr" {
  type    = string
}


variable "public_subnet_cidrs" {
  type    = list(string)
}


variable "private_subnet_cidrs" {
  type    = list(string)
}


variable "allowed_ssh_cidr" {
  type = string
}


variable "key_name" {
  type = string
}


variable "public_instance_ami" {
  type = string
}

variable "private_instance_ami" {
  type = string
}