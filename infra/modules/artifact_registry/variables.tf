variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Repository location"
  type        = string
  default     = "us-central1"
}

variable "repository_id" {
  description = "Repository ID"
  type        = string
  default     = "images-genai-dev-gcp101"
}

variable "description" {
  description = "Repository description"
  type        = string
  default     = "Docker repository for development images"
}

variable "service_account_email" {
  description = "Email of the service account that needs access"
  type        = string
  default     = ""
}