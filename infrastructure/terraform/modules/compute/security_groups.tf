# CloudMart backend compute — Phase 5 (ALB + Auto Scaling Group).
#
# Every rule here is a standalone aws_vpc_security_group_*_rule resource
# rather than an inline ingress/egress block on aws_security_group. Two
# reasons: (1) the ALB and backend security groups reference each other
# (ALB's egress points at backend, backend's ingress points at ALB) — a
# circular reference that inline blocks on both sides can't express
# cleanly; (2) AWS's Terraform provider explicitly warns that mixing
# inline rule blocks with separate rule resources on the SAME security
# group causes rule-management conflicts on every subsequent plan. Using
# standalone rules everywhere avoids both problems.

resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "CloudMart ALB — rules managed as separate resources below"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_from_internet" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet — the one deliberate public entry point"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_backend" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Only to the backend app port — not egress-all"
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.backend.id
}

resource "aws_security_group" "backend" {
  name        = "${var.project}-${var.environment}-backend-sg"
  description = "CloudMart backend — rules managed as separate resources below"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-backend-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "backend_from_alb" {
  security_group_id            = aws_security_group.backend.id
  description                  = "App port reachable only from the ALB — never from the internet directly"
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "backend_all_outbound" {
  security_group_id = aws_security_group.backend.id
  description       = "All outbound — still required with no NAT Gateway: instances reach the internet via their own public IP through the existing IGW"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
