# health_check_type = "ELB" (not the EC2-status-only default) so the ASG
# uses the target group's HTTP health check to judge instance health, not
# just whether the EC2 host is running — this is what lets it detect an
# app-level failure (e.g. the Node process crashed) and replace the
# instance, not just an OS-level one.
resource "aws_autoscaling_group" "backend" {
  name                = "${var.project}-${var.environment}-backend-asg"
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [aws_lb_target_group.backend.arn]

  desired_capacity = var.desired_capacity
  min_size         = var.min_size
  max_size         = var.max_size

  health_check_type         = "ELB"
  health_check_grace_period = 180 # time for user_data (Node install, git clone, npm install) to finish before health checks count against a new instance

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-${var.environment}-backend"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "terraform"
    propagate_at_launch = true
  }
}
