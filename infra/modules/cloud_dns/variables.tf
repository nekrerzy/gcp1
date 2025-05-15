variable "project_id" {
  description = "ID of the Google Cloud project"
  type        = string
}

variable "managed_zone_name" {
  description = "Name of the existing managed DNS zone"
  type        = string
}

variable "dns_records" {
  description = "Map of DNS records to create"
  type = map(object({
    name    = string
    type    = string
    ttl     = number
    rrdatas = list(string)
  }))
}
