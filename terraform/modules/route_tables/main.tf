# --------------------------------------
# PUBLIC ROUTE TABLE
# --------------------------------------
resource "aws_route_table" "public_rt" {
  vpc_id = var.vpc_id
  tags   = { Name = "tf-public-rt" }
}


# Default route to Internet Gateway
resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id
}


# Associate public subnets with public route table
resource "aws_route_table_association" "public_assoc" {
  count          = length(var.public_subnet_ids)
  subnet_id      = var.public_subnet_ids[count.index]
  route_table_id = aws_route_table.public_rt.id
}


# --------------------------------------
# PRIVATE ROUTE TABLE
# --------------------------------------
resource "aws_route_table" "private_rt" {
  vpc_id = var.vpc_id
  tags   = { Name = "tf-private-rt" }
}


# Route private traffic via NAT
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_id
}


# Associate private subnets
resource "aws_route_table_association" "private_assoc" {
  count          = length(var.private_subnet_ids)
  subnet_id      = var.private_subnet_ids[count.index]
  route_table_id = aws_route_table.private_rt.id
}
