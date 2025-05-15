##############################
# 1. Project & Environment
##############################

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "environment" {
  description = "The environment for the resources (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "The GCP region where resources will be created"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone within the region for zonal resources"
  type        = string
  default     = "us-central1-a"
}

variable "unique_suffix" {
  description = "Unique suffix for resource names"
  type        = string
  default     = "gcp101"
}


##############################
# 2. Network & VPC
##############################

variable "network_option" {
  description = "Option to create a new VPC or use an existing one (create_new or use_existing)"
  type        = string
  default     = "create_new"
}

variable "existing_vpc_name" {
  description = "Name of existing VPC when network_option is use_existing"
  type        = string
  default     = ""
}

variable "existing_subnet_name" {
  description = "Name of existing subnet when network_option is use_existing"
  type        = string
  default     = ""
}

variable "subnets" {
  description = "List of subnet configurations (name, cidr, region, secondary_ranges)"
  type = list(object({
    name          = string
    ip_cidr_range = string
    region        = string
    secondary_ranges = list(object({
      range_name    = string
      ip_cidr_range = string
    }))
  }))
  default = []
}

variable "firewall_rules" {
  description = "List of firewall rules to create"
  type = list(object({
    name        = string
    direction   = string
    priority    = number
    description = string
    ranges      = list(string)
    allow = list(object({
      protocol = string
      ports    = list(string)
    }))
    deny = list(object({
      protocol = string
      ports    = list(string)
    }))
    target_tags             = list(string)
    source_tags             = list(string)
    source_service_accounts = list(string)
    target_service_accounts = list(string)
  }))
  default = []
}

variable "nat_router_name" {
  description = "Name of the Cloud NAT router"
  type        = string
  default     = "nat-router-genai-dev-gcp101"
}

variable "nat_name" {
  description = "Name of the Cloud NAT configuration"
  type        = string
  default     = "nat-config-genai-dev-gcp101"
}

variable "service_networking_range" {
  description = "IP CIDR range for private service access (Cloud SQL, Redis, etc.)"
  type        = string
  default     = "10.100.0.0/22"
}


##############################
# 3. API Enablement
##############################

variable "apis_to_enable" {
  description = "List of Google Cloud APIs to enable for this project"
  type        = list(string)
  default     = []
}


##############################
# 4. Cloud SQL / Database
##############################

variable "db_instance_name" {
  description = "Name of the Cloud SQL instance"
  type        = string
  default     = "postgres-genai-dev-gcp101"
}

variable "db_version" {
  description = "PostgreSQL version to use"
  type        = string
  default     = "POSTGRES_17"
}

variable "db_tier" {
  description = "Machine type for the database instance"
  type        = string
  default     = "db-g1-small"
}

variable "db_edition" {
  description = "Cloud SQL edition (ENTERPRISE or ENTERPRISE_PLUS)"
  type        = string
  default     = "ENTERPRISE"
}

variable "db_availability_type" {
  description = "Availability type for Cloud SQL instance"
  type        = string
  default     = "ZONAL"
}

variable "db_disk_size" {
  description = "Storage size in GB"
  type        = number
  default     = 20
}

variable "db_disk_type" {
  description = "Type of storage (PD_SSD or PD_HDD)"
  type        = string
  default     = "PD_SSD"
}

variable "db_backup_enabled" {
  description = "Whether to enable automated backups"
  type        = bool
  default     = true
}

variable "db_backup_start_time" {
  description = "Time when backups should start (HH:MM format)"
  type        = string
  default     = "02:00"
}

variable "db_name" {
  description = "Name of the default database to create"
  type        = string
  default     = "app_db"
}

variable "db_user" {
  description = "Name of the default database user"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Password for the default user (leave blank for auto-generation)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "database_flags" {
  description = "Database flags for the Cloud SQL instance"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    { name = "cloudsql.enable_pgaudit", value = "on" },
    { name = "log_checkpoints", value = "on" },
    { name = "log_disconnections", value = "on" },
    { name = "log_min_duration_statement", value = "-1" },
    { name = "log_min_messages", value = "warning" },
    { name = "log_temp_files", value = "0" },
    { name = "log_lock_waits", value = "on" },
    { name = "max_connections", value = "100" }
  ]
}

variable "db_deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = false
}


##############################
# 5. GKE & Service Accounts
##############################

variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "genai-dev-gcp101-cluster"
}

variable "gke_service_account_roles" {
  description = "Roles assigned to the GKE cluster service account"
  type        = list(string)
  default = [
    "roles/container.defaultNodeServiceAccount",
    "roles/artifactregistry.reader",
    "roles/storage.objectViewer"
  ]
}

variable "pods_service_account_roles" {
  description = "Roles assigned to the GKE pods service account"
  type        = list(string)
  default = [
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
}

variable "espv2_service_account_roles" {
  description = "Roles assigned to the ESPV2 service account"
  type        = list(string)
  default = [
    "roles/servicemanagement.admin"
  ]
}


##############################
# 6. Storage
##############################

variable "storage_location" {
  description = "Location for storage buckets"
  type        = string
  default     = ""
}

variable "storage_buckets" {
  description = "List of storage bucket configurations"
  type = list(object({
    name               = string
    force_destroy      = optional(bool, true)
    storage_class      = optional(string, "STANDARD")
    versioning_enabled = optional(bool, false)
    lifecycle_rules = optional(list(object({
      age_days      = optional(number, 30)
      action        = optional(string, "Delete")
      storage_class = optional(string)
    })), [])
    labels = optional(map(string), {})
  }))
  default = [
    { name = "app-data" },
    { name = "app-media", versioning_enabled = true },
    { name = "vertex-ai-data", versioning_enabled = true }
  ]
}


##############################
# 7. Firestore & Document AI
##############################

variable "firestore_collections" {
  description = "List of Firestore collections to create"
  type        = list(string)
  default     = ["users", "products", "orders"]
}

variable "document_ai_location" {
  description = "Location for Document AI processors"
  type        = string
  default     = "us"
}


##############################
# 8. Security Policy (Cloud Armor)
##############################

variable "enable_cloud_armor" {
  description = "Whether to create the Cloud Armor security policy"
  type        = bool
  default     = true
}


variable "security_policy_ddos_ip_ranges_1" {
  description = "List of IP ranges for the first DDoS rate limiting rule"
  type        = list(string)
  default = [
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
}

variable "security_policy_ddos_ip_ranges_2" {
  description = "List of IP ranges for the second DDoS rate limiting rule"
  type        = list(string)
  default = [
    "154.113.23.0/24",
    "165.225.0.0/17",
    "165.225.192.0/18",
    "185.46.212.0/22",
    "197.98.201.0/24",
    "211.144.19.0/24",
    "213.52.102.0/24"
  ]
}

variable "security_policy_rate_limit_count" {
  description = "Number of requests to allow before rate limiting"
  type        = number
  default     = 100
}

variable "security_policy_rate_limit_interval" {
  description = "Interval in seconds for rate limit threshold"
  type        = number
  default     = 60
}

variable "security_policy_ban_duration_sec" {
  description = "Ban duration in seconds for rate limited IPs"
  type        = number
  default     = 300
}


