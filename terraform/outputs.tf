output "public_instance_ip" {
  value = module.public_ec2.instance_ips
}


output "private_instance_ids" {
  value = module.private_ec2.instance_ids
}