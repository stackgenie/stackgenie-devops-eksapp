#-----------------------------------------------------------------------------------------------------------
# Global variables
#-----------------------------------------------------------------------------------------------------------

variable "owner" {
  default = "stackgenie"
}

variable "environment" {
  type = string
}
#-----------------------------------------------------------------------------------------------------------
# VPC Vars
#-----------------------------------------------------------------------------------------------------------

variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(any)
}

variable "private_subnets" {
  type = list(any)
}

variable "public_subnets" {
  type = list(any)
}

variable "vpc_enable_nat_gateway" {
  default = true
}
variable "vpc_single_nat_gateway" {
  default = true
}
