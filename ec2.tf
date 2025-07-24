# EC2 Primary
resource "aws_instance" "primary_instance" {
    ami = var.ami_id_primary
    instance_type = var.instance_type
    subnet_id = aws_subnet.primary_subnet_1.id
    key_name = var.key_name
    associate_public_ip_address = true
    vpc_security_group_ids = [aws_security_group.primary_sg.id]
    tags = {
        Name = "${var.disaster_recovery}-primary"
    }
}

# EC2 Secondary
resource "aws_instance" "secondary_instance" {
    provider = aws.secondary
    ami = var.ami_id_secondary
    instance_type = var.instance_type
    subnet_id = aws_subnet.secondary_subnet_2.id
    key_name = var.key_name
    associate_public_ip_address = true
    vpc_security_group_ids = [aws_security_group.secondary_sg.id]
    tags = {
        Name = "${var.disaster_recovery}-secondary"
    }
}
