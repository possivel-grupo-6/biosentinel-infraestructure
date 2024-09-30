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

  tags = {
    Name = "${var.client}-public-rt"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
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

resource "tls_private_key" "docker_node_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_private_key" "jupyter_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "docker_node_private_key" {
  content  = tls_private_key.docker_node_key.private_key_pem
  filename = "${path.module}/docker_node_key.pem"
}

resource "local_file" "jupyter_private_key" {
  content  = tls_private_key.jupyter_key.private_key_pem
  filename = "${path.module}/jupyter_key.pem"
}

resource "aws_key_pair" "docker_node_key" {
  key_name   = "docker_node_key"
  public_key = tls_private_key.docker_node_key.public_key_openssh
}

resource "aws_key_pair" "jupyter_key" {
  key_name   = "jupyter_key"
  public_key = tls_private_key.jupyter_key.public_key_openssh
}


resource "aws_instance" "docker_node" {
  ami                    = var.ec2_ami_id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.docker_node_key.key_name
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
    sudo apt install -y awscli
    aws s3api put-object --bucket bucket-${var.client}-trusted --key geolocalizacao/
    aws s3api put-object --bucket bucket-${var.client}-trusted --key temperatura-batimento/
    aws s3api put-object --bucket bucket-${var.client}-trusted --key temperatura-umidade/
    aws s3api put-object --bucket bucket-${var.client}-trusted --key pressao-arterial/
    aws s3api put-object --bucket bucket-${var.client}-trusted --key som/
    aws s3api put-object --bucket bucket-${var.client}-trusted --key presenca/
  EOF
}

resource "aws_instance" "jupyter_notebook" {
  ami                    = var.ec2_ami_id
  instance_type          = "t2.small"
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.jupyter_key.key_name
  iam_instance_profile   = var.ec2_iam_instance_profile
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  tags = {
    Name = "${var.client}-jupyter-notebook"
  }

  user_data = <<-EOF
    #!/bin/bash
    amazon-linux-extras install java-openjdk11 -y
    curl -O https://dlcdn.apache.org/spark/spark-3.2.1/spark-3.2.1-bin-hadoop3.2.tgz
    tar xzf spark-3.2.1-bin-hadoop3.2.tgz -C /usr/local --owner root --group root --no-same-owner
    rm -rf spark-3.2.1-bin-hadoop3.2.tgz
    mv /usr/local/spark-3.2.1-bin-hadoop3.2 /usr/local/spark
    pip3 install pyspark --no-cache-dir
    pip3 install jupyterlab --no-cache-dir
    echo "[Unit]
    Description=Jupyter Notebook
    [Service]
    Type=simple
    ExecStart=/opt/jupyter/script/start.sh
    Restart=always
    RestartSec=10
    [Install]
    WantedBy=multi-user.target" > /lib/systemd/system/jupyter.service
    mkdir -p /opt/jupyter/{notebook,script}
    echo '#!/bin/bash
    /usr/bin/python3 -m notebook --NotebookApp.notebook_dir=/opt/jupyter/notebook --NotebookApp.password=$(/usr/bin/python3 -c "from notebook.auth import passwd; print(passwd(\"${var.ec2_jupyter_password}\"))") --allow-root --ip 0.0.0.0 --port 80' > /opt/jupyter/script/start.sh
    chmod +x /opt/jupyter/script/start.sh
    systemctl daemon-reload
    systemctl start jupyter
    systemctl enable jupyter
  EOF
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
