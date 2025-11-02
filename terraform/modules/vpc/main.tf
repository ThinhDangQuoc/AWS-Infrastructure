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

# Private subnets
resource "aws_subnet" "private" {
  for_each                = toset(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  map_public_ip_on_launch = false
  tags                    = { Name = "tf-private-${each.key}" }
}

# Elastic IP for NAT
resource "aws_eip" "nat_eip" {
  vpc = true
  tags = { Name = "nat-eip" }
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


resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  ingress = []
  egress  = []
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


resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 365   # giữ log ít nhất 1 năm
  kms_key_id        = aws_kms_key.cloudwatch_key.arn  # mã hóa log
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "kms_policy" {
  statement {
    sid = "AllowCloudWatchLogsPut"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com", "vpc-flow-logs.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.logs_key.arn]
  }

  statement {
    sid = "AllowAccountAdmins"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
      "kms:DescribeKey",
      "kms:EnableKeyRotation",
      "kms:ListKeys",
      "kms:UpdateKeyDescription"
    ]
    resources = [aws_kms_key.logs_key.arn]
  }
}

resource "aws_kms_key" "cloudwatch_key" {
  description = "KMS key for CloudWatch logs encryption"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms_policy.json
}


resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vpc/flow-logs:*"
    }]
  })
}

resource "aws_flow_log" "vpc_flow_log" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn
}
