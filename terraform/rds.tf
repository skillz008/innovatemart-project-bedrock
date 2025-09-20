# main-rds.tf

# For the Orders RDS (PostgreSQL) Module
module "db_orders" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.project_name}-orders"

  # Reference the new variables
  engine               = "postgresql"
  engine_version       = var.db_engine_version["postgres"]  # <-- This references the new variable
  instance_class       = var.rds_instance_class
  allocated_storage    = var.rds_allocated_storage

  db_name  = var.rds_orders_db_name
  username = var.rds_orders_username
  password = var.rds_orders_password
  port     = "5432"

  # DISABLE OPTION GROUP FOR POSTGRESQL
  create_db_option_group = false

  # Database parameter group configuration
  family = var.db_parameter_group_family["postgres"]  # <-- This references the new variable
  
  # Option group configuration (if needed)
  major_engine_version = split(".", var.db_engine_version["postgres"])[0]  # Extracts "15" from "15.4"

  vpc_security_group_ids = [module.eks.cluster_primary_security_group_id]
  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets

  skip_final_snapshot = true

  tags = {
    Project = var.project_name
  }
}

# For the Catalog RDS (MySQL) Module
module "db_catalog" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.project_name}-catalog"

  # Reference the new variables
  engine               = "mysql"
  engine_version       = var.db_engine_version["mysql"]  # <-- This references the new variable
  instance_class       = var.rds_instance_class
  allocated_storage    = var.rds_allocated_storage

  db_name  = var.rds_catalog_db_name
  username = var.rds_catalog_username
  password = var.rds_catalog_password
  port     = "3306"

  # DISABLE OPTION GROUP FOR MYSQL
  create_db_option_group = false

  # Database parameter group configuration
  family = var.db_parameter_group_family["mysql"]  # <-- This references the new variable
  
  # Option group configuration (if needed)
  major_engine_version = split(".", var.db_engine_version["mysql"])[0]  # Extracts "8" from "8.0.33"

  vpc_security_group_ids = [module.eks.cluster_primary_security_group_id]
  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets

  skip_final_snapshot = true

  tags = {
    Project = var.project_name
  }
}
