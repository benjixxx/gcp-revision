# ==============================================================================
# Database Module Outputs
# ==============================================================================

output "instance_name" {
  description = "The name of the database instance"
  value       = google_sql_database_instance.postgres.name
}

output "instance_connection_name" {
  description = "The connection name of the instance to be used in connection strings or Cloud SQL Proxy"
  value       = google_sql_database_instance.postgres.connection_name
}

output "public_ip_address" {
  description = "The first public (IPv4) address of the database instance"
  value       = google_sql_database_instance.postgres.public_ip_address
}

output "private_ip_address" {
  description = "The first private (IPv4) address of the database instance"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "database_name" {
  description = "The name of the default database created"
  value       = google_sql_database.database.name
}

output "database_user" {
  description = "The name of the database user created"
  value       = google_sql_user.user.name
}

