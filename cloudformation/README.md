# 🌩️ CloudFormation AWS Infrastructure

Dự án này triển khai hạ tầng AWS bao gồm:
- **VPC** (có Public và Private Subnet)
- **Internet Gateway**, **NAT Gateway**
- **Route Tables** cho từng subnet
- **Security Groups**
- **EC2 Instances** (Public và Private)

Mục tiêu là xây dựng môi trường AWS chuẩn có khả năng:
- Truy cập Internet từ Public EC2
- Private EC2 kết nối ra ngoài qua NAT Gateway
- SSH từ Public EC2 (Bastion Host) sang Private EC2

---

## 🚀 1️⃣ Yêu cầu môi trường

### Công cụ cần thiết
- [AWS CLI](https://aws.amazon.com/cli/)
- Tài khoản AWS có đủ quyền tạo VPC, EC2, S3, IAM, CloudFormation

### Kiểm tra phiên bản
```bash
aws --version
```

---

## 🔑 2️⃣ Tạo AWS Key Pair (để SSH vào EC2) và Access Key cho AWS Configure

### **Tạo AWS Key Pair**
1. Mở AWS Console → **EC2 → Key Pairs → Create key pair**
2. Đặt tên ví dụ: `my-aws-keypair`
3. Chọn loại file: `.pem`
4. Lưu file về máy, ví dụ: `~/.ssh/tf-key.pem`
5. Cấp quyền cho file:
   ```bash
   chmod 400 ~/.ssh/tf-key.pem
   ```

### **Tạo Access Key**
1. Mở AWS Console → **IAM → Users**
2. Chọn user ví dụ: `cloud-user`
3. Chọn tab **Security credentials**
4. Trong phần **Access keys**, click **Create access key**
5. Lưu **Access Key ID** và **Secret Access Key** (cần dùng cho aws configure)

## ⚙️ 3️⃣ Cấu hình AWS CLI

Chạy lệnh
```bash
cd cloudformation
aws configure
```

Nhập thông tin:
```bash
AWS Access Key ID [None]: <your-access-key-id>
AWS Secret Access Key [None]: <your-secret-access-key>
Default region name [None]: us-east-1
Default output format [None]: json
```

Kiểm tra lại:
```bash
aws sts get-caller-identity
```

## 🧱 4️⃣ Cấu trúc thư mục dự án CloudFormation

```bash
cloudformation/
├── main.yml
├── parameters.json
├── bucket-policy.json
├── tests
├── modules/
│   ├── vpc.yml
│   ├── subnet.yml
│   ├── route_tables.yml
│   ├── nat_gateway.yml
│   ├── ec2.yml
│   └── security_groups.yml
└── README.md
```

---

## 🧩 5️⃣ Điều chỉnh tham số CloudFormation

Trước khi chạy, cần đảm bảo các biến trong file `parameters.json` phù hợp với tài khoản và vùng AWS của bạn.

Ví dụ:
```hcl
[
  {
    "ParameterKey": "VPCCIDR",
    "ParameterValue": "10.0.0.0/16"
  },
  {
    "ParameterKey": "PublicSubnetCIDR",
    "ParameterValue": "10.0.1.0/24"
  },
  {
    "ParameterKey": "PrivateSubnetCIDR",
    "ParameterValue": "10.0.2.0/24"
  },
  {
    "ParameterKey": "MyIP",
    "ParameterValue": "203.0.113.12/32"
  },
  {
    "ParameterKey": "KeyPairName",
    "ParameterValue": "my-aws-keypair"
  },
  {
    "ParameterKey": "AmiId",
    "ParameterValue": "ami-002ccb478420d8d9c"
  },
  {
    "ParameterKey": "InstanceType",
    "ParameterValue": "t2.micro"
  }
]
```

---

## 🪄 6️⃣ Các bước triển khai hạ tầng bằng CloudFormation

### **Bước 1: Tạo S3 Bucket chứa Templates**
```bash
aws s3 mb s3://my-cloudformation-templates-thinhdan905 --region us-east-1   
```

### **Bước 2: Thiết lập Policy cho S3 Bucket**
```bash
aws s3api put-bucket-policy \
  --bucket my-cloudformation-templates-thinhdan905 \
  --policy file://bucket-policy.json
```

Đảm bảo policy cho phép CloudFormation đọc các template.

### **Bước 3: Upload Templates lên S3**
```bash
aws s3 cp main.yml s3://my-cloudformation-templates-thinhdan905/
aws s3 cp modules/vpc.yml s3://my-cloudformation-templates-thinhdan905/
aws s3 cp modules/subnet.yml s3://my-cloudformation-templates-thinhdan905/
aws s3 cp modules/nat-gateway.yml s3://my-cloudformation-templates-thinhdan905/
aws s3 cp modules/route-tables.yml s3://my-cloudformation-templates-thinhdan905/
aws s3 cp modules/security-groups.yml s3://my-cloudformation-templates-thinhdan905/
aws s3 cp modules/ec2.yml s3://my-cloudformation-templates-thinhdan905/   
```

Kiểm tra file đã có trong bucket:
```bash
aws s3 ls s3://my-cloudformation-templates-thinhdan905/
```
Bạn phải thấy tất cả module và `main.yml`.

### **Bước 4: Tạo Stack**
```bash
aws cloudformation create-stack \
  --stack-name MyVPCStack \
  --template-url https://my-cloudformation-templates-thinhdan905.s3.amazonaws.com/main.yml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

### **Bước 4.5: Cập nhật Stack (nếu cần)**
```bash
aws cloudformation update-stack \
  --stack-name MyVPCStack \
  --template-url https://my-cloudformation-templates-thinhdan905.s3.amazonaws.com/main.yml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

## 🧪 7️⃣ Kiểm thử hạ tầng sau khi triển khai

### **Kiểm tra trực quan trên AWS Console**
1. Mở AWS Console → **CloudFormation → Stacks**
2. Chọn stack `MyVPCStack`
3. Kiểm tra trạng thái:
- `CREATE_IN_PROGRESS` → stack đang được tạo
- `CREATE_COMPLETE` → stack đã tạo thành công
- `ROLLBACK_COMPLETE` → có lỗi trong quá trình tạo
4. Mở **Resources** để xem danh sách tất cả resource đã được tạo:
- VPC
- Subnets (Public / Private)
- Internet Gateway
- NAT Gateway
- Route Tables
- Security Groups
- EC2 Instances
5. Có thể vào **VPC** để xem chi tiết trong AWS Console

### **Chạy testcase có sẵn**
```bash
tests/test_cf.sh
```

Nếu đúng hết tất cả sẽ hiển thị
```pgsql
✅ ALL NETWORK TEST CASES PASSED SUCCESSFULLY!
```

## 🧹 8️⃣ Dọn dẹp và các lệnh CloudFormation hữu ích

### **Xóa Stack**
```bash
aws cloudformation delete-stack --stack-name MyVPCStack --region us-east-1
```