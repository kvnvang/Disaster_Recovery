variable "disaster_recovery" {
    description = "Disaster Recovery"
    default = "CloudSleuth-DR"
}

variable "primary_region" {
    description = "Primary AWS Region"
    type = string
    default = "us-east-2"
}

variable "secondary_region" {
    description = "DR Region"
    type = string
    default = "us-west-2"
}

variable "instance_type" {
    description = "ec2 instance type"
    type = string
    default = "t3.micro"
}

variable "ami_id_primary" {
    description = "AMI ID for primary region"
    default = "ami-0c02fb55956c7d316" # Example AMI ID for us-east-2
}

variable "ami_id_secondary" {
    description = "AMI ID for secondary region"
    default = "ami-0e34e7b9ca0ace12d" # Example AMI ID for us-west-2
}

variable "key_name" {
    description = "SSH key pair name" # Name of the SSH key pair to use
    type = string
}

variable "sns_email" {
  description = "Email address to receive SNS alerts"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging resources"
  type        = string
}

variable "admin_cidr_block" {
  description = "CIDR block for SSH administrative access"
  type        = string
}
