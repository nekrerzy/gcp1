output "repository_id" {
  description = "ID of the created repository"
  value       = google_artifact_registry_repository.docker_repo.repository_id
}



output "repository_url" {
  description = "URL del repositorio para Docker"
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
}