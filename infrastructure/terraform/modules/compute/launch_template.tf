# Looked up dynamically, same reasoning as Phase 3's AZ lookup and Phase
# 4's AMI lookup: not every account has the same AMI IDs available, and a
# hardcoded ID goes stale. Free, read-only API call.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_launch_template" "backend" {
  name_prefix   = "${var.project}-${var.environment}-backend-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }

  vpc_security_group_ids = [aws_security_group.backend.id]

  metadata_options {
    http_tokens = "required" # IMDSv2 only — same hardening as Phase 4
  }

  # Detailed (1-minute) CloudWatch monitoring deliberately left off (the
  # default) — it has a per-instance charge; standard 5-minute metrics are
  # free and sufficient for this phase.

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Instance tags come from the Auto Scaling Group's own `tag` blocks
  # (propagate_at_launch = true) in asg.tf, not from tag_specifications
  # here, to avoid tagging the same instance from two places.

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    repo_url    = var.repo_url
    repo_branch = var.repo_branch
    app_port    = var.app_port
  }))

  tags = {
    Name = "${var.project}-${var.environment}-backend-lt"
  }
}
