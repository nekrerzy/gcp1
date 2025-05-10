output "database_id" {
  description = "ID of the Firestore database"
  value       = google_firestore_database.database.name
}

output "database_name" {
  description = "Full name of the Firestore database"
  value       = google_firestore_database.database.id
}

output "location" {
  description = "Location of the Firestore database"
  value       = var.location_id
}

output "collections" {
  description = "Collections initialized in Firestore"
  value       = var.collections
}
