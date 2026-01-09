# VPC
resource "aws_vpc" "tobi_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

# SUBNET
resource "aws_subnet" "tobi_subnet" {
  vpc_id                  = aws_vpc.tobi_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "dev-public"
  }
}

# INTERNET GATEWAY
resource "aws_internet_gateway" "tobi_gw" {
  vpc_id = aws_vpc.tobi_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

# ROUTE TABLE
resource "aws_route_table" "tobi_public_rt" {
  vpc_id = aws_vpc.tobi_vpc.id

  tags = {
    Name = "dev_public_rt"
  }
}

# ROUTE
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.tobi_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.tobi_gw.id
}

# ROUTE TABLE ASSOCIATION
resource "aws_route_table_association" "tobi_public_assoc" {
  subnet_id      = aws_subnet.tobi_subnet.id
  route_table_id = aws_route_table.tobi_public_rt.id
}

# SECURITY GROUP
resource "aws_security_group" "tobi_sg" {
  name        = "dev_sg"
  description = "dev security group"
  vpc_id      = aws_vpc.tobi_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Not best practice
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# KEY PAIR
resource "aws_key_pair" "tobi_auth" {
  key_name   = "vscodekey"
  public_key = file("~/.ssh/vscodekey.pub")
}

# EC2 INSTANCE
resource "aws_instance" "dev_node" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.tobi_auth.id
  vpc_security_group_ids = [aws_security_group.tobi_sg.id]
  subnet_id              = aws_subnet.tobi_subnet.id
  user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "dev-node"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname     = self.public_ip,
      user         = "ubuntu",
      identityfile = "~/.ssh/vscodekey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }
}