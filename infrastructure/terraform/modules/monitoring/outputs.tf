output "sns_topic_arn" {
  description = "ARN of the alarm notification topic. Subscribe additional endpoints (email, SMS, another SNS topic, etc.) without any Terraform changes via the AWS Console or CLI if desired."
  value       = aws_sns_topic.alarms.arn
}

output "active_alarm_count" {
  description = "How many alarms actually exist right now (vs. designed-but-inert ones waiting on Phase 5/6)."
  value = sum([
    1, # cloudfront_5xx_error_rate — always active
    length(aws_cloudwatch_metric_alarm.alb_5xx_count),
    length(aws_cloudwatch_metric_alarm.alb_unhealthy_hosts),
    length(aws_cloudwatch_metric_alarm.alb_target_response_time),
    length(aws_cloudwatch_metric_alarm.asg_cpu_high),
    length(aws_cloudwatch_metric_alarm.rds_cpu_high),
    length(aws_cloudwatch_metric_alarm.rds_free_storage_low),
    length(aws_cloudwatch_metric_alarm.rds_connections_high),
  ])
}
