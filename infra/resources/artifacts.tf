module "artifact_registry" {
  source = "../modules/artifact_registry"

  project_id    = var.project_id
  location      = var.region
  repository_id = "ar-${var.project_id}-${var.environment}-${var.unique_suffix}"


  service_account_email = module.gke_service_account.service_account_email

  depends_on = [
    time_sleep.wait_for_apis
  ]
}
