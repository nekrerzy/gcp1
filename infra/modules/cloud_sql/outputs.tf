

output "instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.name
}

output "instance_id" {
  description = "The ID of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.id
}

output "instance_connection_name" {
  description = "The connection name of the instance to be used in connection strings"
  value       = google_sql_database_instance.instance.connection_name
}

output "instance_self_link" {
  description = "The URI of the instance"
  value       = google_sql_database_instance.instance.self_link
}

output "instance_ip_address" {
  description = "The IPv4 address of the instance"
  value       = google_sql_database_instance.instance.private_ip_address
}

output "instance_first_ip_address" {
  description = "The first IPv4 address of the addresses assigned"
  value       = google_sql_database_instance.instance.first_ip_address
}

output "database_name" {
  description = "The name of the database"
  value       = google_sql_database.database.name
}

output "user_name" {
  description = "The name of the user"
  value       = google_sql_user.user.name
}

output "user_password" {
  description = "The password of the user"
  value       = var.user_password != "" ? var.user_password : random_password.user_password.result
  sensitive   = true
}

output "instance_server_ca_cert" {
  description = "The CA certificate information used to connect to the database instance"
  value       = google_sql_database_instance.instance.server_ca_cert
  sensitive   = true
}

output "connection_string" {
  description = "The connection string to use to connect to the PostgreSQL instance"
  value       = "postgresql://${google_sql_user.user.name}:${var.user_password != "" ? var.user_password : random_password.user_password.result}@${google_sql_database_instance.instance.private_ip_address}/${google_sql_database.database.name}"
  sensitive   = true
}
