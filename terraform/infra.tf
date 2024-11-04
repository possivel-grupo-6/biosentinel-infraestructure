provider "aws" {
  region = "us-east-1"
}


resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.client}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.client}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.client}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.client}-public-rt"
  }
}
resource "aws_route_table_association" "rt_assoc_subnet_1" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.client}-sg"
  }
}



resource "aws_instance" "docker_node" {
  ami                    = var.ec2_ami_id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  key_name               = "ssh-key"
  iam_instance_profile   = var.ec2_iam_instance_profile
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  tags = {
    Name = "Docker-node"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y docker.io python3 python3-pip git
    sudo pip3 install docker-compose
  EOF
}

resource "aws_instance" "jupyter_notebook" {
  ami                    = var.ec2_ami_id
  instance_type          = "t2.small"
  subnet_id              = aws_subnet.public.id
  key_name               = "ssh-key"
  iam_instance_profile   = var.ec2_iam_instance_profile
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  tags = {
    Name = "${var.client}-jupyter-notebook"
  }

provisioner "file" {
  source      = "scripts.tar"  
  destination = "/tmp/scripts.tar"

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("ssh-key.pem")
    host        = self.public_ip
  }
}

provisioner "remote-exec" {
  inline = [
    "cd /tmp",
    "tar -xf /tmp/scripts.tar",  
    "chmod +x /tmp/scripts/configjupyter.sh",       
    "bash /tmp/scripts/configjupyter.sh"
  ]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("ssh-key.pem")
    host        = self.public_ip
  }
}

}

resource "aws_s3_bucket" "bucket_trusted" {
  bucket = "bucket-${var.client}-trusted"
  acl    = "private"

  tags = {
    Name = "bucket-${var.client}-trusted"
  }
}

resource "aws_s3_bucket" "bucket_client" {
  bucket = "bucket-${var.client}-client"
  acl    = "private"

  tags = {
    Name = "bucket-${var.client}-client"
  }
}
