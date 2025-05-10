resource "google_firestore_database" "database" {
  project                           = var.project_id
  name                              = var.database_id
  location_id                       = var.location_id
  type                              = var.type
  delete_protection_state     = var.delete_protection_state
  app_engine_integration_mode = var.app_engine_integration_mode
  point_in_time_recovery_enablement = var.point_in_time_recovery_enabled
  
  deletion_policy = "DELETE"
}
