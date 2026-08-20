# The topic itself is free regardless of subscriber count or notification
# volume within AWS's standard SNS free tier (1,000 email notifications/month
# — effectively unlimited for a portfolio project's alarm volume). The
# subscription is opt-in: no email is hardcoded anywhere in this repo:
# see variables.tf.

resource "aws_sns_topic" "alarms" {
  name = "${var.project}-${var.environment}-alarms"

  tags = {
    Name = "${var.project}-${var.environment}-alarms"
  }
}

resource "aws_sns_topic_subscription" "alarms_email" {
  count = var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
