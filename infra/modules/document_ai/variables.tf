variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Location for Document AI"
  type        = string
  default     = "us"
}

variable "service_account_email" {
  description = "Service account email to access Document AI"
  type        = string
}

variable "processors" {
  description = "List of Document AI processors to create"
  type = list(object({
    display_name = string
    type         = string
    timeout      = optional(number, 300)
    labels       = optional(map(string), {})
  }))
  default = []
}
