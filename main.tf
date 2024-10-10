# # Provider Configuration
# provider "aws" {
#   region = var.region
# }

# # Create a VPC
# resource "aws_vpc" "main" {
#   cidr_block = var.vpc_cidr
#   tags = {
#     Name = var.vpc_name
#   }
# }

# # Create Internet Gateway
# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.main.id
#   tags = {
#     Name = "${var.vpc_name}-igw"
#   }
# }

# # Create Public Subnets
# resource "aws_subnet" "public" {
#   for_each = { for i, cidr in var.public_subnet_cidrs : i => cidr }

#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = each.value
#   availability_zone       = element(var.availability_zones, tonumber(each.key))
#   map_public_ip_on_launch = true

#   tags = {
#     Name = "${var.vpc_name}-public-${tonumber(each.key) + 1}"
#   }
# }

# # Create Private Subnets
# resource "aws_subnet" "private" {
#   for_each = { for i, cidr in var.private_subnet_cidrs : i => cidr }

#   vpc_id            = aws_vpc.main.id
#   cidr_block        = each.value
#   availability_zone = element(var.availability_zones, tonumber(each.key))

#   tags = {
#     Name = "${var.vpc_name}-private-${tonumber(each.key) + 1}"
#   }
# }

# # Create Public Route Table
# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.main.id

#   tags = {
#     Name = "${var.vpc_name}-public-rt"
#   }
# }

# # Create Public Route in Public Route Table
# resource "aws_route" "public_internet_route" {
#   route_table_id         = aws_route_table.public.id
#   destination_cidr_block = "0.0.0.0/0"
#   gateway_id             = aws_internet_gateway.igw.id
# }

# # Associate Public Subnets with Public Route Table
# resource "aws_route_table_association" "public_association" {
#   for_each       = aws_subnet.public
#   subnet_id      = each.value.id
#   route_table_id = aws_route_table.public.id
# }

# # Create Private Route Table
# resource "aws_route_table" "private" {
#   vpc_id = aws_vpc.main.id

#   tags = {
#     Name = "${var.vpc_name}-private-rt"
#   }
# }

# # Associate Private Subnets with Private Route Table
# resource "aws_route_table_association" "private_association" {
#   for_each       = aws_subnet.private
#   subnet_id      = each.value.id
#   route_table_id = aws_route_table.private.id
# }

# # Outputs
# output "vpc_id" {
#   description = "The ID of the VPC"
#   value       = aws_vpc.main.id
# }

# output "public_subnet_ids" {
#   description = "Map of public subnet IDs"
#   value       = { for k, v in aws_subnet.public : k => v.id }
# }

# output "private_subnet_ids" {
#   description = "Map of private subnet IDs"
#   value       = { for k, v in aws_subnet.private : k => v.id }
# }

# output "internet_gateway_id" {
#   description = "The ID of the Internet Gateway"
#   value       = aws_internet_gateway.igw.id
# }
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