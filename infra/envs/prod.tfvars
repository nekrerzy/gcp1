#################################################
# Environment & Naming
#################################################
unique_suffix = "gcp101"

#################################################
# Cloud SQL / Database
#################################################
db_version             = "POSTGRES_17"
db_tier                = "db-n2-standard-2"
db_edition             = "ENTERPRISE_PLUS"
db_availability_type   = "REGIONAL"
db_disk_size           = 300
db_disk_type           = "PD_SSD"
db_backup_enabled      = true
db_backup_start_time   = "01:00"
db_name                = "app_db"
db_user                = "postgres"
db_password            = ""
db_deletion_protection = true

#################################################
# Document AI
#################################################
document_ai_location = "us"

#################################################
# Storage Buckets
#################################################
storage_buckets = [
  {
    name               = "app-data-prod"
    storage_class      = "STANDARD"
    force_destroy      = false
    versioning_enabled = true
    labels = {
      env      = "prod"
      critical = "true"
    }
  },
  {
    name               = "app-media-prod"
    storage_class      = "MULTI_REGIONAL"
    force_destroy      = false
    versioning_enabled = true
    labels = {
      env = "prod"
    }
  },
  {
    name               = "vertex-ai-data-prod"
    storage_class      = "STANDARD"
    force_destroy      = false
    versioning_enabled = true
    labels = {
      env = "prod"
    }
  }
]

#################################################
# Firestore
#################################################
firestore_collections = ["users", "products", "orders"]

#################################################
# Service Account Roles
#################################################
gke_service_account_roles = [
  "roles/container.defaultNodeServiceAccount",
  "roles/artifactregistry.reader",
  "roles/storage.objectViewer"
]

pods_service_account_roles = [
  "roles/logging.logWriter",
  "roles/storage.admin",
  "roles/cloudsql.client",
  "roles/redis.viewer",
  "roles/aiplatform.user",
  "roles/datastore.user",
  "roles/documentai.apiUser",
  "roles/documentai.viewer",
  "roles/secretmanager.admin",
  "roles/servicemanagement.serviceController"
]

espv2_service_account_roles = [
  "roles/servicemanagement.admin"
]

#################################################
# Security Policy (Cloud Armor)
#################################################
security_policy_ddos_ip_ranges_1 = [
  "103.237.80.15/32",
  "103.237.80.10/32",
  "38.110.174.130/32",
  "58.220.95.0/24",
  "94.188.131.0/25",
  "104.129.192.0/20",
  "128.177.125.0/24",
  "136.226.0.0/16",
  "137.83.128.0/18",
  "147.161.128.0/17"
]

security_policy_ddos_ip_ranges_2 = [
  "190.62.19.235/32",
  "154.113.23.0/24",
  "165.225.0.0/17",
  "165.225.192.0/18",
  "185.46.212.0/22",
  "197.98.201.0/24",
  "211.144.19.0/24",
  "213.52.102.0/24"
]

security_policy_rate_limit_count    = 80 # More strict for prod
security_policy_rate_limit_interval = 60
security_policy_ban_duration_sec    = 600 # Longer ban for prod
