

resource "google_artifact_registry_repository" "docker_repo" {
  
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  format        = "docker"
  description   = var.description
  

  labels = {
    managed-by  = "terraform"
  }

  
}

