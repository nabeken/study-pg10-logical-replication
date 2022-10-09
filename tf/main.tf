data "aws_region" "default" {}

#
# Create VPC
#
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs = var.availability_zones

  public_subnets   = var.public_subnets
  database_subnets = var.database_subnets
}

#
# Create a bastion EC2 instance w/ ssm-agent in the intra subnets
#
module "ec2-bastion-server" {
  source  = "cloudposse/ec2-bastion-server/aws"
  version = "0.30.1"

  namespace = var.project_name
  name      = "bastion"

  ami_filter = {
    name = ["amzn2-ami-hvm-2.*-arm64-gp2"]
  }

  instance_type = var.bastion_instance_type

  vpc_id                      = module.vpc.vpc_id
  security_groups             = [module.vpc.default_security_group_id]
  subnets                     = module.vpc.public_subnets
  associate_public_ip_address = true
}

#
# Create a publisher RDS with PostgreSQL 10
#
resource "aws_db_instance" "pg10" {
  engine         = "postgres"
  engine_version = var.pg10_version
  instance_class = var.db_instance_type

  allocated_storage = 10
  storage_type      = "gp2"
  storage_encrypted = true

  multi_az             = false
  db_subnet_group_name = module.vpc.database_subnet_group_name

  # this password should be only used for bootstrap and should be changed after the creation
  username = "postgres"
  password = "Lie?th7ees<udooseixi"

  parameter_group_name = "default.postgres10"
  skip_final_snapshot  = true
}

#
# Create a subscirber RDS with PostgreSQL 14
#
resource "aws_db_instance" "pg14" {
  engine         = "postgres"
  engine_version = var.pg14_version
  instance_class = var.db_instance_type

  allocated_storage = 10
  storage_type      = "gp2"
  storage_encrypted = true

  multi_az             = false
  db_subnet_group_name = module.vpc.database_subnet_group_name

  # this password should be only used for bootstrap and should be changed after the creation
  username = "postgres"
  password = "Lie?th7ees<udooseixi"

  parameter_group_name = "default.postgres14"
  skip_final_snapshot  = true
}
