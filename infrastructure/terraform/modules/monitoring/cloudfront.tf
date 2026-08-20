# CloudFront's standard metrics (Requests, error rates, bytes) report to
# CloudWatch at no extra cost, at 5-minute granularity, in us-east-1 only
# (a CloudFront quirk — the distribution is global, but its CloudWatch
# metrics are only visible in us-east-1) — no "additional metrics" opt-in
# needed for 5xxErrorRate specifically. This is the one alarm in this
# module that's meaningful today, since Phase 7 is the only tier deployed.
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_error_rate" {
  alarm_name          = "${var.project}-${var.environment}-cloudfront-5xx-error-rate"
  alarm_description   = "CloudFront 5xx error rate exceeded 5% — likely an origin (S3) problem, since nothing dynamic sits behind this distribution yet."
  namespace           = "AWS/CloudFront"
  metric_name         = "5xxErrorRate"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching" # no traffic = no errors, not an alarm condition

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Name = "${var.project}-${var.environment}-cloudfront-5xx-error-rate"
  }
}
