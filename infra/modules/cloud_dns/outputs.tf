output "dns_records" {
  description = "Registros DNS creados"
  value       = google_dns_record_set.registros
}

output "zone_name_servers" {
  description = "Servidores de nombres de la zona DNS"
  value       = data.google_dns_managed_zone.zona_existente.name_servers
}
