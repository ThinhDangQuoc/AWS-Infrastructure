resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "tf-vpc" }
}


# --------------------------------------
# PUBLIC SUBNETS
# --------------------------------------
resource "aws_subnet" "public" {
  for_each                = toset(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  tags                    = { Name = "tf-public-${each.key}" }
}

# --------------------------------------
# PRIVATE SUBNETS
# --------------------------------------
resource "aws_subnet" "private" {
  for_each                = toset(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  map_public_ip_on_launch = false
  tags                    = { Name = "tf-private-${each.key}" }
}


# --------------------------------------
# INTERNET GATEWAY
# --------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "igw" }
}


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
  subnet_id     = element(values(aws_subnet.public)[*].id, 0)
  tags          = { Name = "tf-nat-gw" }
}


# --------------------------------------
# PUBLIC ROUTE TABLE
# --------------------------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "tf-public-rt" }
}


# Default route to Internet Gateway
resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id

  depends_on = [aws_internet_gateway.igw]
}


# Associate public subnets with public route table
resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}


# --------------------------------------
# PRIVATE ROUTE TABLE
# --------------------------------------
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "tf-private-rt" }
}


# Route private traffic via NAT
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id

  depends_on = [aws_nat_gateway.nat]
}


# Associate private subnets
resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_rt.id
}


# --------------------------------------
# DEFAULT SECURITY GROUP
# --------------------------------------
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  ingress = []
  egress  = []

  tags = {
    Name        = "default-sg"
  }
}

# --------------------------------------
# IAM ROLE for EC2 (for SSM & Logging)
# ------------------------------------
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


# --------------------------------------
# KMS Key for VPC Flow Logs
# --------------------------------------
# resource "aws_kms_key" "logs_key" {
#   description             = "KMS key for encrypting VPC Flow Logs and CloudWatch Logs"
#   deletion_window_in_days = 7
#   enable_key_rotation     = true
#   policy                  = data.aws_iam_policy_document.kms_policy.json

#   tags = {
#     Name = "tf-vpc-logs-key"
#   }
# }


# # Optional alias for easier reference
# resource "aws_kms_alias" "logs_key_alias" {
#   name          = "alias/vpc-logs-key"
#   target_key_id = aws_kms_key.logs_key.key_id
# }


# data "aws_iam_policy_document" "kms_policy" {
#   # Allow only account root to manage this specific KMS key
#   statement {
#     sid = "AllowRootAccountFullAccess"
#     principals {
#       type        = "AWS"
#       identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
#     }
#     actions   = [
#       "kms:Create*",
#       "kms:Describe*",
#       "kms:Enable*",
#       "kms:List*",
#       "kms:Put*",
#       "kms:Update*",
#       "kms:Revoke*",
#       "kms:Disable*",
#       "kms:Get*",
#       "kms:Delete*",
#       "kms:TagResource",
#       "kms:UntagResource",
#       "kms:ScheduleKeyDeletion",
#       "kms:CancelKeyDeletion"
#     ]
#     resources = [aws_kms_key.logs_key.arn]
#   }

#   # Allow CloudWatch and VPC Flow Logs to use the key for encryption
#   statement {
#     sid = "AllowCloudWatchLogsPut"
#     effect = "Allow"
#     principals {
#       type        = "Service"
#       identifiers = ["logs.${data.aws_region.current.id}.amazonaws.com", "vpc-flow-logs.amazonaws.com"]
#     }
#     actions = [
#       "kms:Encrypt",
#       "kms:Decrypt",
#       "kms:GenerateDataKey*",
#       "kms:DescribeKey"
#     ]
#     resources = [aws_kms_key.logs_key.arn]
#   }

#    # Allow account admins read-only and rotation permissions
#   statement {
#     sid = "AllowAccountAdmins"
#     effect = "Allow"
#     principals {
#       type = "AWS"
#       identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
#     }
#     actions = [
#       "kms:DescribeKey",
#       "kms:EnableKeyRotation",
#       "kms:ListKeys",
#       "kms:UpdateKeyDescription"
#     ]
#     resources = [aws_kms_key.logs_key.arn]
#   }
# }

# --------------------------------------
# KMS Key for CloudWatch Logs
# --------------------------------------
resource "aws_kms_key" "cloudwatch_key" {
  description         = "KMS key for encrypting CloudWatch Logs and VPC Flow Logs"
  enable_key_rotation = true

  tags = {
    Name        = "tf-cloudwatch-key"
  }
}

resource "aws_kms_key_policy" "cloudwatch_policy" {
  key_id = aws_kms_key.cloudwatch_key.key_id
  policy = data.aws_iam_policy_document.cloudwatch_kms_policy.json
}

resource "aws_kms_alias" "cloudwatch_key_alias" {
  name          = "alias/tf-cloudwatch-key"
  target_key_id = aws_kms_key.cloudwatch_key.key_id
}

data "aws_iam_policy_document" "cloudwatch_kms_policy" {
  # Allow only account root to manage this specific KMS key
  statement {
    sid = "AllowAccountRootKMSManagement"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ]
    resources = [ aws_kms_key.cloudwatch_key.arn ]
  }

  # Allow CloudWatch Logs service principal to use the key for encrypt/decrypt
  statement {
    sid = "AllowCloudWatchLogsUsage"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "logs.${data.aws_region.current.id}.amazonaws.com",
        "vpc-flow-logs.amazonaws.com"
      ]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [ aws_kms_key.cloudwatch_key.arn ]
  }
}

# --------------------------------------
# CLOUDWATCH LOGS for VPC FLOW
# --------------------------------------
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 365   # giữ log ít nhất 1 năm
  kms_key_id        = aws_kms_key.cloudwatch_key.arn  # mã hóa log

   depends_on = [aws_kms_key.cloudwatch_key]
}


# IAM Role for VPC Flow Logs
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


# IAM Policy for VPC Flow Logs
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


# Create Flow Logs
resource "aws_flow_log" "vpc_flow_log" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn
}

# --------------------------------------
# DATA SOURCES
# --------------------------------------
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}