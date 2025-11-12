# 🌩️ Terraform AWS Infrastructure

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
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [AWS CLI](https://aws.amazon.com/cli/)
- Một tài khoản AWS hợp lệ (với quyền tạo EC2, VPC, NAT, v.v.)

### Kiểm tra phiên bản
```bash
terraform -v
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


---

## ⚙️ 3️⃣ Cấu hình AWS CLI

Chạy lệnh
```bash
cd terraform
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

## 🧱 4️⃣ Cấu trúc thư mục dự án Terraform

```bash
terraform-aws/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── tests
├── modules/
│   ├── vpc/
│   ├── route_tables/
│   ├── nat_gateway/
│   ├── ec2/
│   └── security_groups/
└── README.md
```

---

## 🧩 5️⃣ Điều chỉnh tham số Terraform

Trước khi chạy, cần đảm bảo các biến trong file `terraform.tfvars` phù hợp với tài khoản và vùng AWS của bạn.

Ví dụ:
```hcl
region               = "us-east-1"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidr   = "10.0.1.0/24"
private_subnet_cidr  = "10.0.2.0/24"
key_name             = "my-aws-keypair"
public_instance_ami  = "ami-053b0d53c279acc90"
private_instance_ami = "ami-053b0d53c279acc90"
```

---

## 🪄 6️⃣ Các bước triển khai hạ tầng bằng Terraform

### **Bước 1: Khởi tạo dự án**
```bash
terraform init
```

### **Bước 2: Kiểm tra cú pháp**
```bash
terraform validate
```

### **Bước 3: Xem kế hoạch triển khai**
```bash
terraform plan -out=tfplan
```

### **Bước 4: Áp dụng thay đổi**
```bash
terraform apply "tfplan"
```
Khi được hỏi:
```pgsql
Do you want to perform these actions?
  Enter a value: yes
```

Nhập **yes** để bắt đầu triển khai.

### **Bước 5: Kiểm tra output**
```bash
terraform output
```


---

## 🧪 7️⃣ Kiểm thử hạ tầng sau khi triển khai

### **Chạy testcase có sẵn**
```bash
tests/test_infr.sh
```

Nếu đúng hết tất cả sẽ hiển thị
```pgsql
✅ ALL NETWORK TEST CASES PASSED SUCCESSFULLY!
```

---

## 🧹 8️⃣ Dọn dẹp và các lệnh Terraform hữu ích

### **Xóa toàn bộ tài nguyên**
```bash
terraform destroy -auto-approve
```
