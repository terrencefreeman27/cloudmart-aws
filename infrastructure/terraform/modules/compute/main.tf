# CloudMart backend compute (Phase 4).
#
# A single EC2 instance in a PUBLIC subnet. No SSH port, and — as of the
# revised design — NO inbound rule for the app port either, by default.
# Primary access is SSM Session Manager port forwarding, which opens zero
# inbound ports at all:
#
#   aws ssm start-session --profile cloudmart --target <instance-id> \
#     --document-name AWS-StartPortForwardingSession \
#     --parameters '{"portNumber":["4000"],"localPortNumber":["4000"]}'
#
# then http://localhost:4000 on your own machine reaches the instance.
#
# var.allowed_demo_cidrs is an explicit, empty-by-default opt-in: if you
# supply CIDR(s) via terraform.tfvars (gitignored) or -var at apply time,
# exactly one ingress rule is added scoped to those CIDRs. Never hardcode a
# real IP into a tracked file — this repo is public.
#
# This intentionally trades some isolation (a private-subnet + ALB design,
# built in Phase 5) for near-zero cost during this learning phase: no NAT
# Gateway, no Elastic IP, no load balancer. See docs/decisions/0006.

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "backend" {
  name        = "${var.project}-${var.environment}-backend-sg"
  description = "CloudMart backend: no SSH, no public app-port access by default (SSM port forwarding only)"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.allowed_demo_cidrs) > 0 ? [var.allowed_demo_cidrs] : []
    content {
      description = "CloudMart API - explicit temporary demo opt-in, not committed to git"
      from_port   = var.app_port
      to_port     = var.app_port
      protocol    = "tcp"
      cidr_blocks = ingress.value
    }
  }

  egress {
    description = "All outbound (package installs, SSM, npm registry)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-backend-sg"
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name = "${var.project}-${var.environment}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project}-${var.environment}-ec2-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project}-${var.environment}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}

resource "aws_instance" "backend" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.backend.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = true

  # No key_name — SSH is not enabled. Shell access is via SSM Session
  # Manager only (aws ssm start-session --target <instance-id>).

  metadata_options {
    http_tokens = "required" # IMDSv2 only — mitigates SSRF-to-credential-theft
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    repo_url    = var.repo_url
    repo_branch = var.repo_branch
    app_port    = var.app_port
  })

  tags = {
    Name = "${var.project}-${var.environment}-backend"
  }
}
