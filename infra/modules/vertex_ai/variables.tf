variable "region" {
  description = "GCP region for the resources"
  type        = string
  default     = "us-central1"

}

variable "network_id" {
  description = "Network ID for the resources"
  type        = string
  default     = "projects/your-project-id/global/networks/your-network-name"

}


variable "vertex_ai_storage_uri" {
  description = "GCS bucket URI for Vertex AI storage"
  type        = string
  default     = "gs://your-bucket-name"

}

variable "environment" {
  description = "Environment for the resources (e.g., dev, prod)"
  type        = string
  default     = "dev"

}


variable "unique_suffix" {
  description = "Unique suffix for resource names"
  type        = string
  default     = "gcp101"

}
