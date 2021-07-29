module "efs" {
  source  = "AustinCloudGuru/efs/aws"
  version = "1.0.7"
  
  depends_on = [
    module.vpc
  ]

  name       = "${var.environment}-${var.owner}-${random_id.id.hex}"
  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id
  security_group_ingress = {
    default = {
      description = "EFS Inbound"
      from_port   = 0
      protocol    = "-1"
      to_port     = 0
      self        = false
      cidr_blocks = [var.vpc_cidr]
      }
  }
  
  lifecycle_policy = [{
    "transition_to_ia" = "AFTER_90_DAYS"
  }]
}
