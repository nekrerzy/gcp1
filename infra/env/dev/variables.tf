
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

# API enablement variables
variable "apis_to_enable" {
  description = "List of Google Cloud APIs to enable for this project"
  type        = list(string)
  default     = []
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

# VPC Service Connection for private service access
variable "service_networking_range" {
  description = "IP CIDR range for private service access (Cloud SQL, Redis, etc.)"
  type        = string
  default     = "10.100.0.0/22" # /22 (1,024 IPs)
}



# Cloud SQL variables
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
  default     = "db-g1-small" # Small machine type for dev
}

variable "db_edition" {
  description = "Cloud SQL edition (ENTERPRISE or ENTERPRISE_PLUS)"
  type        = string
  default     = "ENTERPRISE"
}

variable "db_availability_type" {
  description = "Availability type for Cloud SQL instance"
  type        = string
  default     = "ZONAL" # ZONAL for dev, REGIONAL for prod
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
    {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    },
    {
      name  = "log_checkpoints"
      value = "on"
    },
    {
      name  = "log_disconnections"
      value = "on"
    },
    {
      name  = "log_min_duration_statement"
      value = "-1"
    },
    {
      name  = "log_min_messages"
      value = "warning"
    },
    {
      name  = "log_temp_files"
      value = "0"
    },
    {
      name  = "log_lock_waits"
      value = "on"
    },
    {
      name  = "max_connections"
      value = "100"
    }
  ]
}

variable "db_deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = false # Set to false for dev, true for prod
}


variable "document_ai_location" {
  description = "Location for Document AI processors"
  type        = string
  default     = "us"
}


# Storage variables
variable "storage_location" {
  description = "Location for storage buckets"
  type        = string
  default     = ""
}


variable "unique_suffix" {
  description = "Unique suffix for bucket names"
  type        = string
  default     = "gcp101"
}

# Storage bucket names and configurations 

variable "storage_buckets" {
  description = "Simplified list of bucket configurations"
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
    {
      name = "app-data"
    },
    {
      name               = "app-media"
      versioning_enabled = true
    },
    {
      name               = "vertex-ai-data"
      versioning_enabled = true
    }
  ]
}


