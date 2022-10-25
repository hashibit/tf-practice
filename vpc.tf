
# VPC

resource "aws_vpc" "chenjie" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = false
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name = "${var.resource_prefix}-VPC-01"
  }
}





##################################################################################
###
### Config for public network, including subnet, route table, and internet gateway
### 
##################################################################################


# Internet Gateway

resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.chenjie.id

  tags = {
    Name = "${var.resource_prefix}-igw-01"
  }
}



# Public Subnet

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.chenjie.id
  cidr_block = var.public_subnet_cidr

  tags = {
    Name = "${var.resource_prefix}-sn-pub-01"
  }
}


# Public Route Table

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.chenjie.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public.id
  }

  tags = {
    Name = "${var.resource_prefix}-rt-pub-01"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}




##################################################################################
###
### Config for private network, connect a NAT to the subnet
### 
##################################################################################



# Private Subnet

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.chenjie.id
  cidr_block = var.private_subnet_cidr

  tags = {
    Name = "${var.resource_prefix}-sn-pvt-01"
  }
}


# EIP for public NAT

resource "aws_eip" "public_ip_for_nat" {
  public_ipv4_pool = "amazon"
  vpc              = true
  timeouts {}

  tags = {
    Name = "${var.resource_prefix}-eip-01"
  }
}

resource "aws_nat_gateway" "public" {
  allocation_id = aws_eip.public_ip_for_nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.resource_prefix}-nat-01"
  }

  depends_on = [aws_internet_gateway.public]
}



# Private Route Table, connect NAT and private subnet

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.chenjie.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.public.id
  }

  tags = {
    Name = "${var.resource_prefix}-rt-pvt-01"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}




##################################################################################
###
### Security group, for public and private
### 
##################################################################################



resource "aws_security_group" "public" {
  name        = "${var.resource_prefix}-sg-pub-01"
  description = "${var.resource_prefix}-sg-pub-01"

  vpc_id = aws_vpc.chenjie.id

  # ssh 22 input from everywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # output to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_prefix}-sg-pub-01"
  }
}



resource "aws_security_group" "private" {
  name        = "${var.resource_prefix}-sg-pvt-01"
  description = "${var.resource_prefix}-sg-pvt-01"

  vpc_id = aws_vpc.chenjie.id

  # ssh 22 input from the public subnet only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.public_subnet_cidr}"]
  }

  # all output to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_prefix}-sg-pvt-01"
  }
}
