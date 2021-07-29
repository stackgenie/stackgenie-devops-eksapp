module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.16.0"

  depends_on = [
    module.vpc,
    module.efs
  ]

  cluster_name    = "${var.environment}-${var.owner}-${random_id.id.hex}"
  cluster_version = "1.21"
  subnets         = concat(module.vpc.public_subnets, module.vpc.private_subnets)
  vpc_id          = module.vpc.vpc_id
  manage_aws_auth = false
  enable_irsa     = true
  workers_group_defaults = {
    instance_type        = "c5a.large"   #AMD based processor
    subnets              = module.vpc.private_subnets
    asg_desired_capacity = 2
    asg_min_size         = 2
    asg_max_size         = 4
  }
  
  node_groups = {
    worker = {
      version = "1.21"
      capacity_type = "SPOT"  #using AWS SPOT instance for testing, should change when it comes to production
    }
  }
}
