data "google_dns_managed_zone" "zona_existente" {
  name    = var.managed_zone_name
  project = var.project_id
}

resource "google_dns_record_set" "registros" {
  for_each     = var.dns_records
  
  name         = "${each.value.name}.${data.google_dns_managed_zone.zona_existente.dns_name}"
  managed_zone = data.google_dns_managed_zone.zona_existente.name
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas
  project      = var.project_id
}