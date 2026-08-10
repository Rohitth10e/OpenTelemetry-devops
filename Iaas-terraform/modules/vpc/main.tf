resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                                           = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}"    = "shared"
  }
}

resource "aws_subnet" "private" {
    count                   = length(var.private_subnet_cidrs)
    vpc_id                  = aws_vpc.main.id
    cidr_block              = var.private_subnet_cidrs[count.index]
    availability_zone       = var.availability_zones[count.index]

    tags = {
        Name                                           = "${var.cluster_name}-private-subnet-${count.index + 1}"
        "kubernetes.io/cluster/${var.cluster_name}"    = "shared"
        "kubernetes.io/role/internal-elb"              = "1"
    }
}

resource "aws_subnet" "public" {
    count                   = length(var.public_subnet_cidrs)
    vpc_id                  = aws_vpc.main.id
    cidr_block              = var.public_subnet_cidrs[count.index]
    availability_zone       = var.availability_zones[count.index]

    map_public_ip_on_launch = true

    tags = {
        Name                                           = "${var.cluster_name}-public-subnet-${count.index + 1}"
        "kubernetes.io/cluster/${var.cluster_name}"    = "shared"
        "kubernetes.io/role/elb"                       = "1"
    }
}

resource "internet_gateway" "main" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name                                           = "${var.cluster_name}-internet-gateway"
        "kubernetes.io/cluster/${var.cluster_name}"    = "shared"
    }
}

resource "route_table" "public" {
    vpc_id = aws_vpc.main.id
    
    route = {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }

    tags = {
        Name                                           = "${var.cluster_name}-public-route-table"
        "kubernetes.io/cluster/${var.cluster_name}"    = "shared"
    }
}

resource "route_table_association" "public" {
    count          = length(var.public_subnet_cidrs)
    subnet_id      = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name                                           = "${var.cluster_name}-private-route-table"
        "kubernetes.io/cluster/${var.cluster_name}"    = "shared"
    }
}

resource "route_table_association" "private" {
    count          = length(var.private_subnet_cidrs)
    subnet_id      = aws_subnet.private[count.index].id
    route_table_id = aws_route_table.private.id
}