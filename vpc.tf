# VPC for Primary Region
resource "aws_vpc" "primary_vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "${var.disaster_recovery}-primary-vpc"
    }
}

# VPC for Secondary Region
resource "aws_vpc" "secondary_vpc" {
    provider = aws.secondary
    cidr_block = "10.1.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "${var.disaster_recovery}-secondary-vpc"
    }
}

# Primary Public Subnet 1
resource "aws_subnet" "primary_subnet_1" {
    vpc_id = aws_vpc.primary_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "${var.primary_region}a"
    map_public_ip_on_launch = true
    tags = {
        Name = "${var.disaster_recovery}-primary-subnet"
    }
}

# Secondary Public Subnet 2
resource "aws_subnet" "secondary_subnet_2" {
    provider = aws.secondary
    vpc_id = aws_vpc.secondary_vpc.id
    cidr_block = "10.1.1.0/24"
    availability_zone = "${var.secondary_region}b"
    map_public_ip_on_launch = true
    tags = {
        Name = "${var.disaster_recovery}-secondary-subnet"
    }
}

# Internet Gateway for Primary
resource "aws_internet_gateway" "primary_igw" {
    vpc_id = aws_vpc.primary_vpc.id
    tags = {
        Name = "${var.disaster_recovery}-primary-igw"
    }
}

# Internet Gateway for Secondary
resource "aws_internet_gateway" "secondary_igw" {
    provider = aws.secondary
    vpc_id = aws_vpc.secondary_vpc.id
    tags = {
        Name = "${var.disaster_recovery}-secondary-igw"
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
        Name = "${var.disaster_recovery}-primary-rt"
    }
}

# Route Table Association for Primary
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
        Name = "${var.disaster_recovery}-secondary-rt"
    }
}

# Route Table Association for Secondary
resource "aws_route_table_association" "secondary_route_table_association" {
    provider = aws.secondary
    subnet_id = aws_subnet.secondary_subnet_2.id
    route_table_id = aws_route_table.secondary_route_table.id
}
