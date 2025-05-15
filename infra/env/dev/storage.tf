
# Generate a random string to use for unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  # Common bucket prefix and suffix for all buckets in this environment

  bucket_suffix = random_id.bucket_suffix.hex


  processed_buckets = [
    for bucket in var.storage_buckets : {
      name              = "${bucket.name}-${local.bucket_suffix}"
      force_destroy     = bucket.force_destroy
      storage_class     = bucket.storage_class
      enable_versioning = bucket.versioning_enabled
      lifecycle_rules   = bucket.lifecycle_rules

      labels = merge(bucket.labels, {
        managed_by    = "terraform"
        original_name = bucket.name
      })
    }
  ]
}

# Import the storage module
module "storage" {
  source = "../../modules/storage"

  project_id    = var.project_id
  location      = var.storage_location
  environment   = var.environment
  unique_suffix = local.bucket_suffix

  # Pass the processed bucket configurations
  buckets = local.processed_buckets

  depends_on = [
    module.pods_service_account
  ]
}
