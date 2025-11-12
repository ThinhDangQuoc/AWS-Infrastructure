output "vpc_id" { 
    value = aws_vpc.this.id 
}

output "public_subnet_ids" { 
    value = values(aws_subnet.public)[*].id 
}

output "private_subnet_ids" { 
    value = values(aws_subnet.private)[*].id 
}

output "igw_id" {
  value = aws_internet_gateway.this.id
}

output "default_sg_id" {
  value = aws_default_security_group.default.id
}
