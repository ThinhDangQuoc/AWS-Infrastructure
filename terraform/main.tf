module "vpc" {
  source               = "./modules/vpc"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}


module "nat" {
  source           = "./modules/nat_gateway"
  public_subnet_ids = module.vpc.public_subnet_ids
}


module "route_tables" {
  source              = "./modules/route_tables"
  vpc_id              = module.vpc.vpc_id
  internet_gateway_id = module.vpc.igw_id
  nat_gateway_id      = module.nat.nat_id
  public_subnet_ids   = [element(module.vpc.public_subnet_ids, 0)]
  private_subnet_ids  = [element(module.vpc.private_subnet_ids, 0)]
}


# create security groups
module "sg" {
  source           = "./modules/security_groups"
  vpc_id           = module.vpc.vpc_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
  # public_sg_id left empty for creation flow; module outputs public and private IDs
}


# deploy a public EC2 in first public subnet
module "public_ec2" {
  source              = "./modules/ec2"
  ami                 = var.public_instance_ami
  instance_type       = var.instance_type
  subnet_ids          = [element(module.vpc.public_subnet_ids, 0)]
  security_group_id   = module.sg.public_sg_id
  key_name            = var.key_name
  associate_public_ip = true
  role                = "public"

  depends_on = [
    module.vpc,
    module.sg
  ]
}


# deploy a private EC2 in first private subnet; only accessible from public EC2 via SG
module "private_ec2" {
  source              = "./modules/ec2"
  ami                 = var.private_instance_ami
  instance_type       = var.instance_type
  subnet_ids          = [element(module.vpc.private_subnet_ids, 0)]
  security_group_id   = module.sg.private_sg_id
  key_name            = var.key_name
  associate_public_ip = false
  role                = "private"

  depends_on = [
    module.vpc,
    module.sg
  ]
}