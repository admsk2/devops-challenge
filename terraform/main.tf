provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "k3s-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "k3s-igw"
  }
}

# Subnets
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_1_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "k3s-public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_2_cidr
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "k3s-public-subnet-2"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "k3s-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "k3s" {
  name        = "allow_k3s"
  description = "Allow k3s traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "K3s API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "K3s kubelet"
    from_port   = 10250
    to_port     = 10250
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
    Name = "allow_k3s"
  }
}

# EC2 Instance for k3s server
resource "aws_instance" "k3s_server" {
  ami           = var.ami_id
  instance_type = "t2.medium"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id              = aws_subnet.public_1.id

  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              curl -sfL https://get.k3s.io | sh -
              kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
              EOF

  tags = {
    Name = "k3s-server"
  }
}

# EC2 Instance for k3s agent
resource "aws_instance" "k3s_agent" {
  ami           = var.ami_id
  instance_type = "t2.small"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id              = aws_subnet.public_2.id

  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              SERVER_IP=${aws_instance.k3s_server.private_ip}
              TOKEN=$(ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ec2-user@$SERVER_IP 'sudo cat /var/lib/rancher/k3s/server/node-token')
              curl -sfL https://get.k3s.io | K3S_URL=https://$SERVER_IP:6443 K3S_TOKEN=$TOKEN sh -
              EOF

  depends_on = [aws_instance.k3s_server]

  tags = {
    Name = "k3s-agent"
  }
}