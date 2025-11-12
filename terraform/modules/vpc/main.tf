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
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "tf-igw" }
}


# --------------------------------------
# DEFAULT SECURITY GROUP
# --------------------------------------
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  ingress = []
  egress  = []

  tags = {
    Name        = "tf-default-sg"
  }
}

# # --------------------------------------
# # IAM ROLE for EC2 (for SSM & Logging)
# # ------------------------------------
# resource "aws_iam_role" "ec2_role" {
#   name = "ec2_role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Action = "sts:AssumeRole",
#       Effect = "Allow",
#       Principal = {
#         Service = "ec2.amazonaws.com"
#       }
#     }]
#   })
# }


# resource "aws_iam_instance_profile" "ec2_profile" {
#   name = "ec2_profile"
#   role = aws_iam_role.ec2_role.name
# }


# # --------------------------------------
# # KMS Key for CloudWatch Logs
# # --------------------------------------
# resource "aws_kms_key" "cloudwatch_key" {
#   description         = "KMS key for encrypting CloudWatch Logs and VPC Flow Logs"
#   enable_key_rotation = true

#   tags = {
#     Name        = "tf-cloudwatch-key"
#   }
# }

# resource "aws_kms_key_policy" "cloudwatch_policy" {
#   key_id = aws_kms_key.cloudwatch_key.key_id
#   policy = data.aws_iam_policy_document.cloudwatch_kms_policy.json
# }

# resource "aws_kms_alias" "cloudwatch_key_alias" {
#   name          = "alias/tf-cloudwatch-key"
#   target_key_id = aws_kms_key.cloudwatch_key.key_id
# }

# data "aws_iam_policy_document" "cloudwatch_kms_policy" {
#   # Allow only account root to manage this specific KMS key
#   statement {
#     sid = "AllowAccountRootKMSManagement"
#     principals {
#       type        = "AWS"
#       identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
#     }
#     actions = [
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
#     resources = [ aws_kms_key.cloudwatch_key.arn ]
#   }

#   # Allow CloudWatch Logs service principal to use the key for encrypt/decrypt
#   statement {
#     sid = "AllowCloudWatchLogsUsage"
#     effect = "Allow"
#     principals {
#       type = "Service"
#       identifiers = [
#         "logs.${data.aws_region.current.id}.amazonaws.com",
#         "vpc-flow-logs.amazonaws.com"
#       ]
#     }
#     actions = [
#       "kms:Encrypt",
#       "kms:Decrypt",
#       "kms:GenerateDataKey*",
#       "kms:DescribeKey"
#     ]
#     resources = [ aws_kms_key.cloudwatch_key.arn ]
#   }
# }

# # --------------------------------------
# # CLOUDWATCH LOGS for VPC FLOW
# # --------------------------------------
# resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
#   name              = "/aws/vpc/flow-logs"
#   retention_in_days = 365   # giữ log ít nhất 1 năm
#   kms_key_id        = aws_kms_key.cloudwatch_key.arn  # mã hóa log

#    depends_on = [aws_kms_key.cloudwatch_key]
# }


# # IAM Role for VPC Flow Logs
# resource "aws_iam_role" "vpc_flow_logs_role" {
#   name = "vpc-flow-logs-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = {
#         Service = "vpc-flow-logs.amazonaws.com"
#       },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }


# # IAM Policy for VPC Flow Logs
# resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
#   name = "vpc-flow-logs-policy"
#   role = aws_iam_role.vpc_flow_logs_role.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Action = [
#         "logs:CreateLogGroup",
#         "logs:CreateLogStream",
#         "logs:PutLogEvents",
#         "logs:DescribeLogGroups",
#         "logs:DescribeLogStreams"
#       ],
#       "Resource": "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vpc/flow-logs:*"
#     }]
#   })
# }


# # Create Flow Logs
# resource "aws_flow_log" "vpc_flow_log" {
#   log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
#   log_destination_type = "cloud-watch-logs"
#   traffic_type         = "ALL"
#   vpc_id               = aws_vpc.this.id
#   iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn
# }

# # --------------------------------------
# # DATA SOURCES
# # --------------------------------------
# data "aws_caller_identity" "current" {}

# data "aws_region" "current" {}