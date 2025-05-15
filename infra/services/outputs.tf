
# Project Info

output "project_number" {
  description = "The project ID"
  value       = data.google_project.project.number
}

# Network Outputs


output "network" {
  description = "The VPC network self link"
  value       = module.networking.network_self_link
}

output "network_name" {
  description = "The name of the VPC network"
  value       = module.networking.network_name
}

output "network_id" {
  description = "The ID of the VPC network"
  value       = module.networking.network_id

}

output "subnets_self_links" {
  description = "The self-links of subnets created"
  value       = module.networking.subnets_self_links
}

output "subnets_names" {
  description = "The names of the subnets created"
  value       = module.networking.subnets_names
}

output "subnets_regions" {
  description = "The regions of the subnets created"
  value       = module.networking.subnets_regions
}

output "subnets_ips" {
  description = "The IP CIDR ranges of the subnets created"
  value       = module.networking.subnets_ips
}

output "nat_ip" {
  description = "The external IP address of the NAT gateway"
  value       = module.networking.nat_ip
}


# Cloud SQL Outputs
output "db_instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = module.cloud_sql.instance_name
}

output "db_connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = module.cloud_sql.instance_connection_name
}

output "db_private_ip" {
  description = "The private IP address of the Cloud SQL instance"
  value       = module.cloud_sql.instance_ip_address
}

output "db_database_name" {
  description = "The name of the database"
  value       = module.cloud_sql.database_name
}

output "db_user_name" {
  description = "The name of the database user"
  value       = module.cloud_sql.user_name
}



# Sensitive outputs - will be hidden in console output
output "db_connection_string" {
  description = "The connection string for the database"
  value       = module.cloud_sql.connection_string
  sensitive   = true
}




# Storage Outputs with Original Name Mapping
output "bucket_names" {
  description = "The names of the storage buckets created"
  value       = module.storage.bucket_names
}


output "bucket_urls" {
  description = "The URLs of the storage buckets created"
  value       = module.storage.bucket_urls
}

# GKE Outputs
output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = module.gke_autopilot.cluster_name
}

output "gke_cluster_endpoint" {
  description = "The endpoint for the GKE cluster"
  value       = module.gke_autopilot.cluster_endpoint
  sensitive   = true
}

output "gke_cluster_dns_endpoint" {
  description = "The DNS endpoint for the GKE cluster"
  value       = module.gke_autopilot.dns_endpoint_config
  sensitive   = false

}

output "gke_cluster_ca_certificate" {
  description = "The CA certificate for the GKE cluster"
  value       = module.gke_autopilot.cluster_ca_certificate
  sensitive   = true
}

output "gke_kubectl_command" {
  description = "Command to configure kubectl for this cluster"
  value       = module.gke_autopilot.kubectl_command
}

output "gke_frontend_ip" {
  description = "The external IP address for the Frontend service"
  value       = module.gke_autopilot.frontend_ip_address

}

output "gke_frontend_ip_name" {
  description = "The name of the external IP address for the Frontend service"
  value       = module.gke_autopilot.frontend_ip_name
}

output "gke_api_ip" {
  description = "The external IP address for the API service"
  value       = module.gke_autopilot.api_ip_address

}

output "gke_api_ip_name" {
  description = "The name of the external IP address for the API service"
  value       = module.gke_autopilot.api_ip_name
}


# Artifact Registry Outputs
output "repository_id" {
  description = "ID of the Artifact Registry repository"
  value       = module.artifact_registry.repository_id
}

output "repository_url" {
  description = "URL for docker images"
  value       = module.artifact_registry.repository_url
}

output "docker_image_path" {
  description = "Base path for your Docker images"
  value       = "${var.region}-docker.pkg.dev/${module.artifact_registry.repository_url}/[image-name]:[tag]"
}

# Security Policy Outputs CLOUD ARMOR

output "security_policy_id" {
  description = "The ID of the created security policy"
  value       = google_compute_security_policy.default.id
}

output "security_policy_name" {
  description = "The name of the created security policy"
  value       = google_compute_security_policy.default.name
}

output "security_policy_self_link" {
  description = "The self link of the security policy"
  value       = google_compute_security_policy.default.self_link
}


# Firestore Outputs
output "firestore_database" {
  description = "ID of the Firestore database"
  value       = module.firestore.database_id
}

output "firestore_location" {
  description = "Location of the Firestore database"
  value       = module.firestore.location
}

output "firestore_collections" {
  description = "Collections available in Firestore"
  value       = module.firestore.collections
}

## Document AI Outputs

output "processor_ids" {
  description = "IDs for the created Document AI processors"
  value       = module.document_ai.processor_ids
}

output "processor_versions" {
  description = "Default versions for the processors"
  value       = module.document_ai.processor_versions
}

output "service_endpoint_ip" {
  description = "Base endpoint for Document AI (if enabled)"
  value       = module.document_ai.service_endpoint
}

output "processor_endpoints" {
  description = "Endpoints for document processing (prediction)"
  value       = module.document_ai.processor_endpoints
}

output "processor_batch_endpoints" {
  description = "Endpoints for batch processing"
  value       = module.document_ai.processor_batch_endpoints
}

## Service Account Outputs
output "gke_service_account_email" {
  description = "Email of the GKE service account"
  value       = module.gke_service_account.service_account_email
}



output "pods_service_account_email" {
  description = "Email of the GKE pods service account"
  value       = module.pods_service_account.service_account_email
}

output "espv2_service_account_email" {
  description = "Email of the ESPv2 service account"
  value       = module.espv2_service_account.service_account_email

}


# Vertex AI Outputs
output "vertex_ai_endpoint_id" {
  description = "The ID of the Vertex AI endpoint."
  value       = module.vertex_ai.vertex_ai_endpoint_id
}
output "vertex_ai_index_id" {
  description = "The ID of the Vertex AI index."
  value       = module.vertex_ai.vertex_ai_index_id
}
output "vertex_ai_index_endpoint_id" {
  description = "The ID of the Vertex AI index endpoint."
  value       = module.vertex_ai.vertex_ai_index_endpoint_id
}
output "vertex_ai_index_endpoint_url" {
  description = "The URL of the Vertex AI index endpoint."
  value       = module.vertex_ai.vertex_ai_index_endpoint_url
}

