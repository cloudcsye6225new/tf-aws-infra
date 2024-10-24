provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_subnets" {
  count             = 3
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnets" {
  count             = 3
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 3)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route" "public_internet_gateway_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

resource "aws_route_table_association" "public_subnet_routes" {
  count          = 3
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_subnet_routes" {
  count          = 3
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "db_sg" {
  name        = "database_sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web_app_sg.id] # Allow traffic from the web app security group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

resource "aws_db_subnet_group" "main_rds_subnet_group" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id
  tags = {
    Name = "${var.project_name}-rds-subnet-group"
  }
}

resource "aws_db_instance" "main_rds" {
  allocated_storage      = 20
  engine                 = var.db_engine
  instance_class         = "db.t3.micro"
  db_subnet_group_name   = aws_db_subnet_group.main_rds_subnet_group.name
  identifier             = var.db_instance_identifier
  username               = var.db_username
  password               = var.db_password
  db_name                = var.db_name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false

  tags = {
    Name = "${var.project_name}-rds"
  }
}



resource "aws_security_group" "web_app_sg" {
  name        = "application_sg"
  description = "Application security group for web apps"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
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
    Name = "${var.project_name}-app-sg"
  }
}

data "aws_ami" "custom_ami" {
  most_recent = true


  filter {
    name   = "name"
    values = ["network_fall_2024-webapp*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "web_app" {
  ami                    = data.aws_ami.custom_ami.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.web_app_sg.id]
  subnet_id              = aws_subnet.public_subnets[0].id

  user_data = <<-EOF
              #!/bin/bash
              # Write environment variables to a file in /opt/csye6225
              echo "DB_HOST=${aws_db_instance.main_rds.endpoint}" >> /opt/csye6225/App_Test/app.env
              echo "DB_USER=${var.db_username}" >> /opt/csye6225/App_Test/app.env
              echo "DB_PASSWORD=${var.db_password}" >> /opt/csye6225/App_Test/app.env
              echo "DB_NAME=${var.db_name}" >> /opt/csye6225/App_Test/app.env
              echo "DB_PORT=${var.db_port}" >> /opt/csye6225/App_Test/app.env

              # Make the file readable by your application (adjust permissions as needed)
              chmod 644 /opt/csye6225/App_Test/app.env
              EOF
  root_block_device {
    volume_size           = 25
    volume_type           = "gp2"
    delete_on_termination = true
  }

  disable_api_termination = false

  tags = {
    Name = "${var.project_name}-web-app-instance"
  }
}
