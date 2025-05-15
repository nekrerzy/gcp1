module "gke_autopilot" {
  source = "../modules/gke_autopilot"

  project_id   = var.project_id
  cluster_name = "gke-${var.project_id}-${var.environment}-${var.unique_suffix}"
  region       = var.region
  regional     = true


  network            = module.networking.network_name
  subnetwork         = module.networking.subnets_names[0] # Use the app-subnet
  pod_range_name     = "pod-range"
  service_range_name = "service-range"



  # Use the service account we created for GKE
  service_account_email = module.gke_service_account.service_account_email

  # Dependencies
  depends_on = [
    module.gke_service_account,
  ]

}

