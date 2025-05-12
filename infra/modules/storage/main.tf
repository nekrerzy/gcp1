

resource "google_storage_bucket" "log_bucket" {
  name                        = "logging_bucket-${var.project_id}-${var.environment}-${var.unique_suffix}"
  location                    = var.location
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }

}



# Add this to get the project number
data "google_project" "current" {
  project_id = var.project_id
}

# Create multiple Cloud Storage buckets based on simple configurations
resource "google_storage_bucket" "buckets" {
  count = length(var.buckets)
  logging {
    log_bucket = google_storage_bucket.log_bucket.id
  }
  public_access_prevention = "enforced"
  name                     = "${var.buckets[count.index].name}-${var.environment}-${var.unique_suffix}"
  project                  = var.project_id
  location                 = var.location
  force_destroy            = try(var.buckets[count.index].force_destroy, true)
  storage_class            = try(var.buckets[count.index].storage_class, "STANDARD")

  # Uniform bucket-level access for better IAM control (default to true)
  uniform_bucket_level_access = true

  # Enable versioning (simple default config)
  versioning {
    enabled = try(var.buckets[count.index].enable_versioning, false)
  }

  # Add lifecycle rules if specified (optional)
  dynamic "lifecycle_rule" {
    for_each = try(var.buckets[count.index].lifecycle_rules, [])

    content {
      condition {
        age = lifecycle_rule.value.age_days
      }

      action {
        type          = lifecycle_rule.value.action
        storage_class = lifecycle_rule.value.action == "SetStorageClass" ? lifecycle_rule.value.storage_class : null
      }
    }
  }


  # Add labels if specified
  labels = try(var.buckets[count.index].labels, {})
}
