output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = google_container_cluster.autopilot.id
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.autopilot.name
}

output "cluster_endpoint" {
  description = "The IP address of the Kubernetes master"
  value       = google_container_cluster.autopilot.endpoint
  sensitive   = true
}

output "dns_endpoint_config" {
  description = "The DNS endpoint configuration for the GKE cluster"
  value       = google_container_cluster.autopilot.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint
  sensitive   = false

}


output "cluster_ca_certificate" {
  description = "The public certificate of the cluster CA"
  value       = base64decode(google_container_cluster.autopilot.master_auth[0].cluster_ca_certificate)
  sensitive   = true
}


output "frontend_ip_address" {
  description = "The global static IP address for GKE ingress"
  value       = google_compute_global_address.frontend.address
}

output "frontend_ip_name" {
  description = "The name of the global static IP address for GKE ingress"
  value       = google_compute_global_address.frontend.name

}

output "api_ip_address" {
  description = "The global static IP address for GKE ingress"
  value       = google_compute_global_address.api.address

}

output "api_ip_name" {
  description = "The name of the global static IP address for GKE ingress"
  value       = google_compute_global_address.api.name
}

output "cluster_location" {
  description = "The location of the GKE cluster"
  value       = google_container_cluster.autopilot.location
}

output "kubectl_command" {
  description = "The command to configure kubectl for this cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.autopilot.name} --dns-endpoint --region=${google_container_cluster.autopilot.location} --project=${var.project_id}"
}




