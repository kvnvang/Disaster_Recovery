terraform {
    required_version = ">= 1.2.0"
    required_providers {
        aws = {
            version = "~> 6.0"
            source = "hashicorp/aws"
        }
    }
}

# Primary Region
provider "aws" {
    alias = "primary"
    region = var.primary_region
}

# Secondary Region
provider "aws" {
    alias = "secondary"
    region = var.secondary_region
}

# VPC for Primary Region
resource "aws_vpc" "primary_vpc" {
    cidr_block = var.primary_vpc_cidr
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "${var.vpc_name}-primary"
    }
}

# VPC for Secondary Region
resource "aws_vpc" "secondary_vpc" {
    provider = aws.secondary
    cidr_block = var.secondary_vpc_cidr
    enable_dns_support = true
    enable_dns_hostnames= true
    tags = {
        Name = "${var.vpc_name}-secondary"
    }
}

# Primary Public Subnet 1
resource "aws_subnet" "primary_subnet_1" {
    vpc_id = aws_vpc.primary_vpc.id
    cidr_block = var.primary_public_subnet_cidr
    availability_zone = "${var.primary_region}a"
    map_public_ip_on_launch = true
    tags = {
        Name = "${var.vpc_name}-primary"
    }
}

# Secondary Public Subnet 2
resource "aws_subnet" "secondary_subnet_2" {
    provider = aws.secondary
    vpc_id = aws_vpc.secondary_vpc.id
    cidr_block = var.secondary_public_subnet_cidr
    availability_zone = "${var.secondary_region}b"
    map_public_ip_on_launch = true
    tags = {
        Name = "${var.vpc_name}-secondary"
    }
}

# Route Table for Primary
resource "aws_route_table" "primary_route_table" {
    vpc_id = aws_vpc.primary_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.primary_igw.id
    }
        tags = {
            Name = "${var.vpc_name}-primary"
    }
}

# Route Table Association of Primary
resource "aws_route_table_association" "primary_route_table_association" {
    subnet_id = aws_subnet.primary_subnet_1.id
    route_table_id = aws_route_table.primary_route_table.id
}

# Route Table for Secondary
resource "aws_route_table" "secondary_route_table" {
    provider = aws.secondary
    vpc_id = aws_vpc.secondary_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.secondary_igw.id
    }
        tags = {
            Name = "${var.vpc_name}-secondary"
    }
}

# Route Table Association of Secondary
resource "aws_route_table_association" "secondary_route_table_association" {
    provider = aws.secondary
    subnet_id = aws_subnet.secondary_subnet_2.id
    route_table_id = aws_route_table.secondary_route_table.id
}

# Internet Gateway for Primary
resource "aws_internet_gateway" "primary_igw" {
    vpc_id = aws_vpc.primary_vpc.id
    tags = {
        Name = "${var.vpc_name}-primary"
    }
}

# Internet Gateway for Secondary
resource "aws_internet_gateway" "secondary_igw" {
    provider = aws.secondary
    vpc_id = aws_vpc.secondary_vpc.id
    tags = {
        Name = "${var.vpc_name}-secondary"
    }
}
