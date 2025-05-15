
data "google_project" "project" {
  depends_on = [time_sleep.wait_for_apis]
}

module "vertex_ai" {
  source = "../modules/vertex_ai"

  region                = var.region
  network_id            = "projects/${data.google_project.project.number}/global/networks/${module.networking.network_name}"
  vertex_ai_storage_uri = module.storage.bucket_urls[2]
  environment           = var.environment
  unique_suffix         = var.unique_suffix

  depends_on = [
    google_service_networking_connection.private_vpc_connection

  ]

}
