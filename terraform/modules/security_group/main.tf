resource "aws_security_group" "public_ec2_sg" {
  name        = "public-ec2-sg"
  description = "Allow SSH from allowed IP"
  vpc_id      = var.vpc_id


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH from admin"
  }


  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS outbound traffic"
  }

  tags = {
    Name = "tf-public-ec2-sg"
  }
}


resource "aws_security_group" "private_ec2_sg" {
  name        = "private-ec2-sg"
  description = "Allow traffic from public EC2 instances"
  vpc_id      = var.vpc_id


  ingress {
    from_port       = var.allowed_from_port
    to_port         = var.allowed_to_port
    protocol        = var.allowed_protocol
    security_groups = var.public_sg_id != null ? [var.public_sg_id] : []
    description     = "From public EC2 SG"
  }


  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound HTTPS only"
  }

  tags = {
    Name = "tf-private-ec2-sg"
  }
}