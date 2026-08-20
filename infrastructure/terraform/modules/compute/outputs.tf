output "alb_dns_name" {
  description = "Public DNS name of the ALB — the stable URL for the backend (http://<value>), unlike Phase 4's per-restart-changing instance IP."
  value       = aws_lb.main.dns_name
}

output "target_group_arn" {
  description = "ARN of the backend target group."
  value       = aws_lb_target_group.backend.arn
}

output "asg_name" {
  description = "Name of the backend Auto Scaling Group."
  value       = aws_autoscaling_group.backend.name
}

output "alb_security_group_id" {
  description = "ID of the ALB security group."
  value       = aws_security_group.alb.id
}

output "backend_security_group_id" {
  description = "ID of the backend security group."
  value       = aws_security_group.backend.id
}

output "launch_template_id" {
  description = "ID of the backend launch template."
  value       = aws_launch_template.backend.id
}

output "ec2_iam_role_name" {
  description = "Name of the backend's IAM instance role — used at the environment level to attach cross-tier permissions (e.g. reading the database's secret) without either module reaching into the other."
  value       = aws_iam_role.ec2_ssm.name
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix, the form CloudWatch alarms need for the AWS/ApplicationELB dimension (not the full ARN) — used by the Phase 8 monitoring module."
  value       = aws_lb.main.arn_suffix
}
