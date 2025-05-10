
# Enable required Google Cloud APIs
resource "google_project_service" "apis" {
  for_each = toset(var.apis)
  
  project = var.project_id
  service = each.value
  
  # Set to false to keep APIs enabled after terraform destroy
  disable_on_destroy = false
  
  timeouts {
    create = "30m"
    update = "40m"
  }
}

# Add a delay to make sure APIs are fully enabled before other resources use them
resource "time_sleep" "api_enablement" {
  depends_on = [google_project_service.apis]
  
  create_duration = "30s"
}

