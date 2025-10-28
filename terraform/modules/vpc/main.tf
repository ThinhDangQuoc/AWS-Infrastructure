resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}


# Public subnets
resource "aws_subnet" "public" {
  for_each                = toset(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  tags                    = { Name = "tf-public-${each.key}" }
}

# Elastic IP for NAT
resource "aws_eip" "nat_eip" {
}


# Internet Gateway for VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
}


# NAT Gateway in first public subnet
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(values(aws_subnet.public)[*].id, 0)
  tags          = { Name = "tf-nat" }
}


# Private subnets
resource "aws_subnet" "private" {
  for_each                = toset(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  map_public_ip_on_launch = false
  tags                    = { Name = "tf-private-${each.key}" }
}


# Route tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "tf-public-rt" }
}


resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}


resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}


resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "tf-private-rt" }
}


resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}


resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_rt.id
}


# Default Security Group placeholder
resource "aws_security_group" "default_sg" {
  name        = "tf-default-sg"
  description = "Default security group for VPC"
  vpc_id      = aws_vpc.this.id
}