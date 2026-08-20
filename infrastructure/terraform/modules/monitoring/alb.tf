# All three alarms are gated on var.enable_alb_alarms (default false) — a
# plain boolean, not a reference to module.compute's output. Deliberately
# decoupled: referencing module.compute.alb_arn_suffix directly would
# create a Terraform dependency edge to that whole module, and a
# `-target=module.monitoring` plan/apply would then try to satisfy it by
# creating module.compute's 8 resources too — confirmed the hard way
# during Phase 8 design. Enabling these when Phase 5 is deployed is a
# deliberate step (flip enable_alb_alarms, set alb_arn_suffix), not an
# automatic side effect.

resource "aws_cloudwatch_metric_alarm" "alb_5xx_count" {
  count = var.enable_alb_alarms ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-alb-5xx-count"
  alarm_description   = "ALB-level 5xx responses (not the backend's own errors — those are HTTPCode_Target_5XX) exceeded threshold, suggesting an ALB or listener configuration problem."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Name = "${var.project}-${var.environment}-alb-5xx-count"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  count = var.enable_alb_alarms ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-alb-unhealthy-hosts"
  alarm_description   = "At least one backend target is failing its health check — the ASG should be replacing it automatically; this alarm is the visibility into that happening."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Name = "${var.project}-${var.environment}-alb-unhealthy-hosts"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  count = var.enable_alb_alarms ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-alb-target-response-time"
  alarm_description   = "Average backend response time exceeded 2 seconds — early warning of an overloaded or struggling instance before it fails health checks outright."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 2
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Name = "${var.project}-${var.environment}-alb-target-response-time"
  }
}
