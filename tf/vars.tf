variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "public_subnets" {
  type = list(string)
  default = [
    "10.30.10.0/24",
    "10.30.11.0/24",
    "10.30.12.0/24",
  ]
}

variable "database_subnets" {
  type = list(string)
  default = [
    "10.30.20.0/24",
    "10.30.21.0/24",
    "10.30.22.0/24",
  ]
}

variable "intra_subnets" {
  type = list(string)
  default = [
    "10.30.30.0/24",
    "10.30.31.0/24",
    "10.30.32.0/24",
  ]
}

variable "pg10_version" {
  type    = string
  default = "10.21"
}

variable "pg14_version" {
  type    = string
  default = "14.4"
}

variable "db_instance_type" {
  type    = string
  default = "db.t3.micro"
}

variable "bastion_instance_type" {
  type    = string
  default = "t4g.micro"
}

variable "availability_zones" {
  type = list(string)
}
