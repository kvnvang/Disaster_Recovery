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