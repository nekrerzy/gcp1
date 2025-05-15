
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region where the Cloud SQL instance will be created"
  type        = string
}

variable "network_id" {
  description = "The VPC network ID where the Cloud SQL instance will be connected"
  type        = string
}

variable "instance_name" {
  description = "The name of the Cloud SQL instance"
  type        = string
}


variable "database_version" {
  description = "The database version to use"
  type        = string
  default     = "POSTGRES_17"
}

variable "tier" {
  description = "The machine type to use"
  type        = string
  default     = "db-g1-small"
}

variable "edition" {
  description = "The Cloud SQL edition to use (ENTERPRISE or ENTERPRISE_PLUS)"
  type        = string
  default     = "ENTERPRISE"
}

variable "availability_type" {
  description = "The availability type for the Cloud SQL instance (REGIONAL for HA or ZONAL for single zone)"
  type        = string
  default     = "ZONAL"
}

variable "disk_size" {
  description = "The size of the disk in GB"
  type        = number
  default     = 10
}

variable "disk_type" {
  description = "The type of disk (PD_SSD or PD_HDD)"
  type        = string
  default     = "PD_SSD"
}

variable "backup_enabled" {
  description = "Whether backups are enabled"
  type        = bool
  default     = true
}

variable "backup_start_time" {
  description = "The start time for backups in format 'HH:MM'"
  type        = string
  default     = "02:00"
}

variable "database_flags" {
  description = "Database flags to set"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "user_name" {
  description = "The name of the default user to create"
  type        = string
  default     = "postgres"
}

variable "user_password" {
  description = "The password for the default user (leave blank to auto-generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "database_name" {
  description = "The name of the default database to create"
  type        = string
  default     = "app_db"
}

variable "private_network" {
  description = "The VPC network to peer with the Cloud SQL instance"
  type        = string
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled"
  type        = bool
  default     = false
}
