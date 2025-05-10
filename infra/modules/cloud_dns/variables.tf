variable "project_id" {
  description = "ID del proyecto de Google Cloud"
  type        = string
}

variable "managed_zone_name" {
  description = "Nombre de la zona DNS gestionada existente"
  type        = string
}

variable "dns_records" {
  description = "Mapa de registros DNS a crear"
  type = map(object({
    name    = string
    type    = string
    ttl     = number
    rrdatas = list(string)
  }))
}
