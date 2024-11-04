variable "client" {
  type    = string
  default = "bio-sentinel"
}

variable "vpc_cidr" {
  type    = string
  default = "10.100.0.0/24"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.100.0.0/24"
}

variable "availability_zone" {
  type    = string
  default = "us-east-1a"
}


variable "ec2_ami_id" {
  type    = string
  default = "ami-0f9fc25dd2506cf6d"
}

variable "ec2_iam_instance_profile" {
  type    = string
  default = "LabInstanceProfile"
}

variable "ec2_jupyter_password" {
  type    = string
  default = "urubu100"
}