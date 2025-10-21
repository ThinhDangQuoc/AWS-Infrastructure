variable "aws_region" {
type = string
default = "us-east-1"
}


variable "vpc_cidr" {
type = string
default = "10.0.0.0/16"
}


variable "public_subnet_cidrs" {
type = list(string)
default = ["10.0.1.0/24"]
}


variable "private_subnet_cidrs" {
type = list(string)
default = ["10.0.2.0/24"]
}


variable "allowed_ssh_cidr" {
type = string
default = "125.235.238.217/32" # change to your IP
}


variable "key_name" {
type = string
}


variable "public_instance_ami" { type = string }
variable "private_instance_ami" { type = string }