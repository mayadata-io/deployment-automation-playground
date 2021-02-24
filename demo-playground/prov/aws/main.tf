provider "aws" {
  region  = var.location
}

resource "aws_key_pair" "keypair" {
  key_name   = "${var.setup_name}-keypair"
  public_key = file(var.ssh_public_key)
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "${var.setup_name}-vpc"
  }
}

resource "aws_subnet" "subnet" {
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.vpc.id
  availability_zone = "${var.location}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.setup_name}-subnet"
  }
}

resource "aws_security_group" "sg" {
name = "${var.setup_name}-allow-all-sg"
vpc_id = aws_vpc.vpc.id
ingress {
  cidr_blocks = ["0.0.0.0/0"]
  from_port = 22
  to_port = 22
  protocol = "tcp"
  }
ingress {
  from_port = 0
  to_port = 0
  protocol = -1
  cidr_blocks = ["0.0.0.0/0"]
}
egress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "vpcgw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.setup_name}-vpc-gw"
  }
}

resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpcgw.id
  }
  tags = {
    Name = "${var.setup_name}-vpc-rt"
  }
}

resource "aws_route_table_association" "vpcrtassociation" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.routetable.id
}

resource "aws_instance" "storage_node" {
  count = var.storage_nodes.count
  associate_public_ip_address = true
  ami = var.image.ami_id
  instance_type = var.storage_nodes.type
  key_name = "${var.setup_name}-keypair"
  subnet_id = aws_subnet.subnet.id
  tags = {
    Name = "${var.setup_name}-storage-${format("%d", count.index)}"
  }
  vpc_security_group_ids = [aws_security_group.sg.id]
  root_block_device {
    delete_on_termination = true
    volume_type = "gp2"
    volume_size = var.storage_nodes.os_disk_size

  }
}

resource "aws_instance" "master_node" {
  count = var.master_nodes.count
  associate_public_ip_address = true
  ami = var.image.ami_id
  instance_type = var.master_nodes.type
  key_name = "${var.setup_name}-keypair"
  security_groups = [aws_security_group.sg.id]
  subnet_id = aws_subnet.subnet.id
  tags = {
    Name = "${var.setup_name}-master-${format("%d", count.index)}"
  }
  root_block_device {
    delete_on_termination = true
    volume_type = "gp2"
    volume_size = var.master_nodes.os_disk_size
  }
}

resource "aws_instance" "worker_node" {
  count = var.worker_nodes.count
  associate_public_ip_address = true
  ami = var.image.ami_id
  instance_type = var.worker_nodes.type
  key_name = "${var.setup_name}-keypair"
  security_groups = [aws_security_group.sg.id]
  subnet_id = aws_subnet.subnet.id
  tags = {
    Name = "${var.setup_name}-worker-${format("%d", count.index)}"
  }
  root_block_device {
    delete_on_termination = true
    volume_type = "gp2"
    volume_size = var.worker_nodes.os_disk_size
  }
}

