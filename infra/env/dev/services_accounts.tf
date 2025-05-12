
# Service Account for GKE (to assign to the cluster)
module "gke_service_account" {
  source = "../../modules/service_accounts"

  project_id         = var.project_id
  service_account_id = "gke-sa-${var.environment}"
  display_name       = "GKE Cluster Service Account for ${var.project_id}-${var.environment}-${var.unique_suffix}"
  description        = "Service account for GKE cluster in ${var.project_id}-${var.environment}-${var.unique_suffix}"

  # Specific roles for the GKE cluster
  roles = [
    "roles/container.defaultNodeServiceAccount",
    "roles/artifactregistry.reader",
    "roles/storage.objectViewer",
  ]

  depends_on = [
    module.api_resources
  ]
}

# Service Account for GKE Pods
module "pods_service_account" {
  source = "../../modules/service_accounts"

  project_id         = var.project_id
  service_account_id = "pods-sa-${var.environment}"
  display_name       = "GKE Pods Service Account for ${var.project_id}-${var.environment}-${var.unique_suffix}"
  description        = "Service account for GKE applications/pods in ${var.project_id}-${var.environment}-${var.unique_suffix}"

  # Specific roles for the pods
  roles = [
    "roles/logging.logWriter",
    "roles/storage.admin",
    "roles/cloudsql.client",
    "roles/redis.viewer",
    "roles/aiplatform.user",
    "roles/datastore.user",
    "roles/documentai.apiUser",
    "roles/documentai.viewer",
    "roles/secretmanager.admin",
    "roles/servicemanagement.serviceController",
  ]

  depends_on = [
    module.api_resources
  ]
}

module "espv2_service_account" {
  source = "../../modules/service_accounts"

  project_id         = var.project_id
  service_account_id = "espv2-sa-${var.environment}"
  display_name       = "ESPV2 Service Account for ${var.project_id}-${var.environment}-${var.unique_suffix}"
  description        = "Service account for ESP2 in ${var.project_id}-${var.environment}-${var.unique_suffix}"

  # Specific roles for the ESPV2
  roles = [
    "roles/servicemanagement.admin",
  ]

  depends_on = [
    module.api_resources
  ]

}
