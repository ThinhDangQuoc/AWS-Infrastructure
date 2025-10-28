resource "aws_instance" "this" {
  count                       = var.instance_count
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = element(var.subnet_ids, count.index)
  key_name                    = var.key_name
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = var.associate_public_ip
  monitoring                  = true
  ebs_optimized               = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  metadata_options {
    http_tokens = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted = true
  }

  tags                        = { Name = "tf-ec2-${var.role}-${count.index}" }
}
