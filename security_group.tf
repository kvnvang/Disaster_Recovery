# Primary Security Group
resource "aws_security_group" "primary_sg" {
    name = "${var.project_name}-primary-sg"
    description = "aws sg from primary region"
    vpc_id = aws_vpc.primary_vpc.id
    provider = aws.primary

    ingress {
        description = "Allow HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.admin_cidr_block]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1" # -1 means all protocols
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "${var.disaster_recovery}-primary-sg"
    }
}

# Secondary Security Group
resource "aws_security_group" "secondary_sg" {
    provider = aws.secondary
    name = "${var.project_name}-secondary-sg"
    vpc_id = aws_vpc.secondary_vpc.id

    ingress {
        description = "Allow HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.admin_cidr_block]
    }
    egress {
        description = "Allow Outbound"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "${var.disaster_recovery}-secondary-sg"
    }
}