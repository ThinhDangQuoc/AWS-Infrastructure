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


# IAM role for EC2 instance
resource "aws_iam_role" "ec2_role" {
  name = "tf-ec2-role-${var.role}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = {
    Name        = "tf-ec2-role-${var.role}"
  }
}

# Optional: attach AmazonSSMManagedInstanceCore policy so you can use Session Manager
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create instance profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "tf-ec2-profile-${var.role}"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name        = "tf-ec2-profile-${var.role}"
  }
}