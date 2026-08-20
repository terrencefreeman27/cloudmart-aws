# Standalone rule resource (not an inline block), same reasoning as
# modules/compute/security_groups.tf: keeps this security group free to
# gain more trusted-source rules later without any risk of the
# inline-vs-standalone conflict the AWS provider warns about.
#
# No egress rule exists at all — RDS doesn't need to initiate outbound
# connections for core database functionality, so this security group is
# left with zero egress rules (the strictest possible default) rather
# than egress-all, unlike the backend's security group which genuinely
# needs outbound internet access.

resource "aws_security_group" "db" {
  name        = "${var.project}-${var.environment}-db-sg"
  description = "CloudMart database — rules managed as separate resources below"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-db-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_backend" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from the backend application security group only — never a CIDR"
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.app_security_group_id
}
