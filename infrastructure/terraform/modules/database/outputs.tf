output "db_instance_id" {
  description = "ID of the RDS instance."
  value       = aws_db_instance.postgres.id
}

output "db_endpoint" {
  description = "Connection endpoint (host:port). Known only after apply."
  value       = aws_db_instance.postgres.endpoint
}

output "db_name" {
  description = "Database name."
  value       = aws_db_instance.postgres.db_name
}

output "db_security_group_id" {
  description = "ID of the database security group."
  value       = aws_security_group.db.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.main.name
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret AWS creates and manages automatically for the master password. Read this at runtime from the backend — never store the password itself anywhere."
  value       = try(aws_db_instance.postgres.master_user_secret[0].secret_arn, null)
}
