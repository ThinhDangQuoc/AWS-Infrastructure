# --------------------------------------
# ELASTIC IP for NAT Gateway
# --------------------------------------
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = { Name = "nat-eip" }
}


# --------------------------------------
# NAT Gateway
# --------------------------------------
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(var.public_subnet_ids, 0)
  tags          = { Name = "tf-nat-gw" }
}