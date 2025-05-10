variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "service_account_id" {
  description = "ID of the service account"
  type        = string
}

variable "display_name" {
  description = "Display name of the service account"
  type        = string
}

variable "description" {
  description = "Description of the service account"
  type        = string
  default     = "Service account created by Terraform"
}

variable "roles" {
  description = "List of IAM roles to assign to the service account"
  type        = list(string)
  default     = []
}
