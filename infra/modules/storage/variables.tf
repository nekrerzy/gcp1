variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "environment" {
  description = "The environment for the resources (dev, staging, prod)"
  type        = string
  default     = "dev"

}

variable "unique_suffix" {
  description = "A unique suffix for bucket names to avoid collisions"
  type        = string
}

variable "location" {
  description = "The location for the Cloud Storage buckets"
  type        = string
  default     = "us-central1"
}

variable "buckets" {
  description = "List of bucket configurations to create"
  type = list(object({
    name              = string
    force_destroy     = optional(bool)
    storage_class     = optional(string)
    enable_versioning = optional(bool)
    lifecycle_rules = optional(list(object({
      age_days      = number
      action        = string
      storage_class = optional(string)
    })))
    labels = optional(map(string))
  }))
  default = []
}

