
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}


variable "apis" {
  description = "List of Google Cloud APIs to enable"
  type        = list(string)
  default = [
    "compute.googleapis.com",             # Compute Engine API - required for VMs, networks, etc.
    "iam.googleapis.com",                 # Identity and Access Management API - required for service accounts and roles
    "dns.googleapis.com",                 # Cloud DNS API - required for DNS configuration
    "servicenetworking.googleapis.com",   # Service Networking API - required for private services access
    "cloudresourcemanager.googleapis.com", # Cloud Resource Manager API - required for project metadata
    "vpcaccess.googleapis.com",           # VPC Access API - required for serverless VPC access
    "appengineflex.googleapis.com",       # App Engine Flexible Environment API
    "redis.googleapis.com",               # Cloud Memorystore for Redis API
    "sqladmin.googleapis.com",            # Cloud SQL Admin API - required for Cloud SQL instances
    "cloudbuild.googleapis.com",           # Cloud Build API - required for App Engine deployments
    "secretmanager.googleapis.com",        # Secret Manager API - required for storing secrets
    "artifactregistry.googleapis.com",     # Artifact Registry API - required for storing Docker images
    "documentai.googleapis.com",          # Document AI API - required for document processing
    "firestore.googleapis.com",            # Firestore API - required for Firestore database
    "aiplatform.googleapis.com"           # Vertex AI API - required for Vertex AI models
  ]
}