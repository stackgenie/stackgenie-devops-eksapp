module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.environment}-${var.owner}-${random_id.id.hex}"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = var.vpc_enable_nat_gateway
  single_nat_gateway = var.vpc_single_nat_gateway

  tags = {
    Terraform   = "true"
    Environment = terraform.workspace
  }
}
