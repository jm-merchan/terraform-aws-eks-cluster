locals {
  # If a VPC id is provided, use it; otherwise use the one created by the vpc sub-module
  vpc_id = var.vpc_id != null ? var.vpc_id : module.vpc[0].vpc_id

  # If subnet ids are provided directly, use them; otherwise use private subnets from the new VPC
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : module.vpc[0].private_subnets

  # Mandatory tags merged with any additional tags supplied by the caller
  common_tags = merge(
    {
      Environment = var.environment
      Owner       = var.owner
      CostCenter  = var.cost_center
      Project     = var.project
      ManagedBy   = "Terraform"
    },
    var.additional_tags,
  )

  # Whether the module should create the VPC
  create_vpc = var.vpc_id == null
}
