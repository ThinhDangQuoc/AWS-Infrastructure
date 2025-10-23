resource "aws_instance" "this" {
  count                       = var.instance_count
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = element(var.subnet_ids, count.index)
  key_name                    = var.key_name
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = var.associate_public_ip
  tags                        = { Name = "tf-ec2-${var.role}-${count.index}" }
}
