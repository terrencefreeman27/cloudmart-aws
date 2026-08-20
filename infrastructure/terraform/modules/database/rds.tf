# CloudMart database — Phase 6.
#
# manage_master_user_password = true means AWS generates and stores the
# master password in a Secrets Manager secret it creates and manages
# automatically — neither Terraform state nor this code ever holds the
# actual password value. This is the modern (GA since 2022) recommended
# pattern, in place of hand-building a random_password + aws_secretsmanager_secret
# pair. See docs/decisions/0008 for the full reasoning.
#
# publicly_accessible = false and storage_encrypted = true are both
# non-negotiable for this design — the former because the database must
# never be reachable outside the VPC, the latter because encryption can
# only be enabled at creation time, not retroactively.

resource "aws_db_instance" "postgres" {
  identifier = "${var.project}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = true

  db_name                     = var.db_name
  username                    = var.master_username
  manage_master_user_password = true
  port                        = var.port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  multi_az = var.multi_az

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:30-mon:05:30"

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  tags = {
    Name = "${var.project}-${var.environment}-postgres"
  }
}
