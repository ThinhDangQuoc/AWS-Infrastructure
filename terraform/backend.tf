terraform {
  backend "s3" {
    bucket         = "thinhdan905"
    key            = "project/infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}
