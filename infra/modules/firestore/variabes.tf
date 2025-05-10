variable "project_id" {
  description = "ID of the GCP project where the Firestore instance will be created"
  type        = string
}

variable "location_id" {
  description = "Multi-regional location for Firestore (nam5, eur3, etc.)"
  type        = string
  default     = "nam5"  # Multi-regional location in North America
}

variable "database_id" {
  description = "ID of the Firestore database"
  type        = string
  default     = "default"  # Most projects use the 'default' database
}

variable "type" {
  description = "Database mode (FIRESTORE_NATIVE or DATASTORE_MODE)"
  type        = string
  default     = "FIRESTORE_NATIVE"
}

variable "delete_protection_state" {
  description = "Delete protection state (PROTECTION_ENABLED or PROTECTION_DISABLED)"
  type        = string
  default     = "DELETE_PROTECTION_DISABLED"  # For development, facilitates cleanup
}

variable "app_engine_integration_mode" {
  description = "App Engine integration mode (ENABLED or DISABLED)"
  type        = string
  default     = "DISABLED"
}

variable "point_in_time_recovery_enabled" {
  description = "Enable point-in-time recovery"
  type        = string
  default     = "POINT_IN_TIME_RECOVERY_DISABLED"  # For development, we can save costs
}

variable "collections" {
  description = "Initial collections to create in Firestore"
  type        = list(string)
  default     = []
}
