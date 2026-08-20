# Scoped to the ASG's AutoScalingGroupName dimension on the standard
# AWS/EC2 namespace — this aggregates CPU across whichever instances the
# ASG currently has, which is the correct pattern for ephemeral,
# self-replacing instances (an alarm on a specific instance ID would stop
# working the moment the ASG replaced that instance). Gated on a plain
# boolean, same reasoning as alb.tf — decoupled from module.compute to
# avoid an accidental dependency edge.
resource "aws_cloudwatch_metric_alarm" "asg_cpu_high" {
  count = var.enable_asg_alarms ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-asg-cpu-high"
  alarm_description   = "Average CPU across the backend Auto Scaling Group exceeded 80% for 10 minutes — capacity may need to be increased, or something is consuming more CPU than expected."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Name = "${var.project}-${var.environment}-asg-cpu-high"
  }
}
