

module "cloud_dns_frontend" {
  source = "../modules/cloud_dns"

  project_id        = var.project_id
  managed_zone_name = "sub-zone-${data.google_project.project.number}"

  dns_records = {
    frontend = {
      name    = "frontend-${var.environment}"
      type    = "A"
      ttl     = 300
      rrdatas = [module.gke_autopilot.frontend_ip_address]
    }

  }
}


module "cloud_dns_backend" {
  source = "../modules/cloud_dns"

  project_id        = var.project_id
  managed_zone_name = "sub-zone-${data.google_project.project.number}"

  dns_records = {
    frontend = {
      name    = "backend-${var.environment}"
      type    = "A"
      ttl     = 300
      rrdatas = [module.gke_autopilot.api_ip_address]
    }

  }
}
