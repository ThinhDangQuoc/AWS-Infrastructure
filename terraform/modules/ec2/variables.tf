variable "ami" { type = string }
variable "instance_type" { type = string, default = "t3.micro" }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "key_name" { type = string }
variable "instance_count" { type = number, default = 1 }
variable "associate_public_ip" { type = bool, default = false }
variable "role" { type = string, default = "app" }