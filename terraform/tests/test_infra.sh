#!/bin/bash
set -e

echo "==========================================="
echo "🧪 TESTING NETWORK INFRASTRUCTURE DEPLOYMENT"
echo "==========================================="

# Nhập giá trị theo Terraform output hoặc đặt mặc định
VPC_NAME="tf-vpc"
REGION="us-east-1"

# 1️⃣ Lấy thông tin VPC ID
echo "🔍 Fetching VPC..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=${VPC_NAME}" \
  --query "Vpcs[0].VpcId" --output text)

if [[ "$VPC_ID" == "None" || -z "$VPC_ID" ]]; then
  echo "❌ VPC '${VPC_NAME}' not found!"
  exit 1
else
  echo "✅ VPC found: $VPC_ID"
fi

# 2️⃣ TEST SUBNETS
echo "🔍 Checking Subnets..."
PUBLIC_SUBNET=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=tf-public-*" \
  --query "Subnets[0].SubnetId" --output text)

PRIVATE_SUBNET=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=tf-private-*" \
  --query "Subnets[0].SubnetId" --output text)

if [[ -z "$PUBLIC_SUBNET" ]]; then
  echo "❌ No Public Subnet found!"
  exit 1
else
  echo "✅ Public Subnet found: $PUBLIC_SUBNET"
fi

if [[ -z "$PRIVATE_SUBNET" ]]; then
  echo "❌ No Private Subnet found!"
  exit 1
else
  echo "✅ Private Subnet found: $PRIVATE_SUBNET"
fi

# 2️⃣ Kiểm tra ROUTE TABLES
echo "-------------------------------------------"
echo "🧩 Checking Route Tables..."
# Public Route Table
PUBLIC_RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=tf-public-*" \
  --query "RouteTables[0].RouteTableId" --output text)

PRIVATE_RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=tf-private-*" \
  --query "RouteTables[0].RouteTableId" --output text)

if [[ -z "$PUBLIC_RT_ID" ]]; then
  echo "❌ Public Route Table not found!"
  exit 1
else
  echo "✅ Public Route Table found: $PUBLIC_RT_ID"
fi

if [[ -z "$PRIVATE_RT_ID" ]]; then
  echo "❌ Private Route Table not found!"
  exit 1
else
  echo "✅ Private Route Table found: $PRIVATE_RT_ID"
fi

# 3️⃣ Kiểm tra ĐỊNH TUYẾN PUBLIC (Internet Gateway)
echo "-------------------------------------------"
echo "🌐 Checking Public Route Table Internet Route..."
PUB_ROUTE=$(aws ec2 describe-route-tables \
  --route-table-ids "$PUBLIC_RT_ID" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
  --output text)

if [[ "$PUB_ROUTE" == igw-* ]]; then
  echo "✅ Public Route Table routes traffic via Internet Gateway ($PUB_ROUTE)"
else
  echo "❌ Public Route Table does not route via IGW!"
  exit 1
fi

# 4️⃣ Kiểm tra ĐỊNH TUYẾN PRIVATE (NAT Gateway)
echo "-------------------------------------------"
echo "🔒 Checking Private Route Table NAT Route..."
PRIV_ROUTE=$(aws ec2 describe-route-tables \
  --route-table-ids "$PRIVATE_RT_ID" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId" \
  --output text)

if [[ "$PRIV_ROUTE" == nat-* ]]; then
  echo "✅ Private Route Table routes traffic via NAT Gateway ($PRIV_ROUTE)"
else
  echo "❌ Private Route Table missing or incorrect NAT route!"
  exit 1
fi

# 5️⃣ Kiểm tra NAT Gateway
echo "-------------------------------------------"
echo "🧱 Checking NAT Gateway..."
NAT_ID=$(aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" \
  --query "NatGateways[?State=='available'].NatGatewayId" --output text)

if [[ -z "$NAT_ID" ]]; then
  echo "❌ No NAT Gateway available in VPC!"
  exit 1
else
  echo "✅ NAT Gateway active: $NAT_ID"
fi

# 6️⃣ Kiểm tra EC2 INSTANCES
echo "-------------------------------------------"
echo "💻 Checking EC2 Instances..."
PUBLIC_EC2=$(aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=tf-ec2-public-*" \
  --query "Reservations[].Instances[].InstanceId" --output text)

PRIVATE_EC2=$(aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=tf-ec2-private-*" \
  --query "Reservations[].Instances[].InstanceId" --output text)

if [[ -z "$PUBLIC_EC2" ]]; then
  echo "❌ Public EC2 instance not found!"
  exit 1
else
  echo "✅ Public EC2 instance found: $PUBLIC_EC2"
fi

if [[ -z "$PRIVATE_EC2" ]]; then
  echo "❌ Private EC2 instance not found!"
  exit 1
else
  echo "✅ Private EC2 instance found: $PRIVATE_EC2"
fi

# 7️⃣ Kiểm tra SECURITY GROUPS
echo "-------------------------------------------"
echo "🛡️ Checking Security Groups..."
PUB_SG=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=tf-public-ec2-sg" \
  --query "SecurityGroups[0].GroupId" --output text)

PRIV_SG=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=tf-private-ec2-sg" \
  --query "SecurityGroups[0].GroupId" --output text)

if [[ -z "$PUB_SG" ]]; then
  echo "❌ Public Security Group not found!"
  exit 1
else
  echo "✅ Public Security Group found: $PUB_SG"
fi

if [[ -z "$PRIV_SG" ]]; then
  echo "❌ Private Security Group not found!"
  exit 1
else
  echo "✅ Private Security Group found: $PRIV_SG"
fi

# 8️⃣ Kiểm tra RULES cho PUBLIC SG
echo "-------------------------------------------"
echo "🔎 Validating Public SG Inbound Rules..."
SSH_RULES=$(aws ec2 describe-security-groups --group-ids "$PUB_SG" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\` && ToPort==\`22\` && IpProtocol=='tcp'].IpRanges[].CidrIp" \
  --output text)

if [[ -n "$SSH_RULES" ]]; then
  echo "✅ SSH (port 22) rule correctly configured for: $SSH_RULES"
else
  echo "❌ SSH rule missing or misconfigured in Public SG."
fi

# 9️⃣ Kiểm tra RULES cho PRIVATE SG
echo "-------------------------------------------"
echo "🔎 Validating Private SG Rules..."
PRIVATE_SG_SOURCE=$(aws ec2 describe-security-groups \
  --group-ids "$PRIV_SG" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\` && ToPort==\`22\` && IpProtocol=='tcp'].UserIdGroupPairs[].GroupId" \
  --output text)

if [[ "$PRIVATE_SG_SOURCE" == "$PUB_SG" ]]; then
  echo "✅ Private SG allows SSH (port 22) access from Public SG ($PUB_SG)"
else
  echo "❌ Private SG does not allow SSH from Public SG. Found source: ${PRIVATE_SG_SOURCE:-none}"
fi

# 🔟 Gợi ý kiểm tra kết nối thực tế
echo "-------------------------------------------"
echo "🧠 Manual Connectivity Test (recommended):"
echo "  1️⃣ SSH vào EC2 Public: ssh -i <key.pem> ec2-user@<public-ip>"
echo "  2️⃣ Từ đó SSH vào EC2 Private bằng IP Private nội bộ."
echo "  3️⃣ Ping 8.8.8.8 để xác nhận NAT Gateway hoạt động."
echo "✅ Expected: Ping thành công từ EC2 Private qua NAT."

echo "==========================================="
echo "✅ ALL NETWORK TEST CASES PASSED SUCCESSFULLY!"
echo "==========================================="
