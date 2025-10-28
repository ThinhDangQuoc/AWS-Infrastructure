module "vpc" {
  source               = "./modules/vpc"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}


# create security groups
module "sg" {
  source           = "./modules/security_group"
  vpc_id           = module.vpc.vpc_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
  # public_sg_id left empty for creation flow; module outputs public and private IDs
  allowed_from_port = 22
  allowed_to_port   = 22
  allowed_protocol  = "tcp"
}


# deploy a public EC2 in first public subnet
module "public_ec2" {
  source              = "./modules/ec2"
  ami                 = var.public_instance_ami
  instance_type       = "t2.micro"
  subnet_ids          = [element(module.vpc.public_subnets, 0)]
  security_group_id   = module.sg.public_sg_id
  key_name            = var.key_name
  associate_public_ip = true
  allowed_ssh_cidr    = var.allowed_ssh_cidr
  role                = "public"
}


# deploy a private EC2 in first private subnet; only accessible from public EC2 via SG
module "private_ec2" {
  source              = "./modules/ec2"
  ami                 = var.private_instance_ami
  instance_type       = "t2.micro"
  subnet_ids          = [element(module.vpc.private_subnets, 0)]
  security_group_id   = module.sg.private_sg_id
  key_name            = var.key_name
  associate_public_ip = false
  role                = "private"
}


output "public_instance_ip" { value = module.public_ec2.instance_ips }
output "private_instance_ids" { value = module.private_ec2.instance_ids }