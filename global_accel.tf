# Global Accelerator
resource "aws_globalaccelerator_accelerator" "dr_accelerator" {
    name = "dr-accelerator"
    ip_address_type = "IPV4"
    enabled = true

    tags = {
        Name = "dr-accelerator"
        Environment = "web-accelerator"
    }
}

# Listener for Global Accelerator (listens for TCP traffic on port 80)
resource "aws_globalaccelerator_listener" "dr_listener" {
  provider         = aws.primary
  accelerator_arn  = aws_globalaccelerator_accelerator.dr_accelerator.id
  client_affinity  = "NONE"
  protocol         = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }
}

# Primary region endpoint group
resource "aws_globalaccelerator_endpoint_group" "primary_endpoint" {
  provider                 = aws.primary
  listener_arn             = aws_globalaccelerator_listener.dr_listener.id
  endpoint_group_region    = var.primary_region
  health_check_path        = "/"
  health_check_port        = 80
  health_check_protocol    = "HTTP"

  endpoint_configuration {
    endpoint_id                    = aws_subnet.primary_subnet_1.id
    weight                         = 100
    client_ip_preservation_enabled = true
  }
}

# Global Accelerator Secondary Endpoint
resource "aws_globalaccelerator_endpoint_group" "secondary_endpoint" {
    provider = aws.secondary
    listener_arn = aws_globalaccelerator_listener.dr_listener.id
    endpoint_group_region = var.secondary_region
    health_check_path = "/"
    health_check_port = 80
    health_check_protocol = "HTTP"

    endpoint_configuration {
        endpoint_id = aws_subnet.secondary_subnet_2.id
        weight = 0 # Ensure traffic is directed to the primary endpoint by default
        client_ip_preservation_enabled = true
    }
}