
module "api_resources" {
  source = "../../modules/api_resources"

  project_id = var.project_id
  apis = [
    "compute.googleapis.com",              # Compute Engine API - required for VMs, networks, etc.
    "apikeys.googleapis.com",              # API Keys API - required for API keys
    "iam.googleapis.com",                  # Identity and Access Management API - required for service accounts and roles
    "dns.googleapis.com",                  # Cloud DNS API - required for DNS configuration
    "servicenetworking.googleapis.com",    # Service Networking API - required for private services access
    "vpcaccess.googleapis.com",            # VPC Access API - required for serverless VPC access
    "redis.googleapis.com",                # Cloud Memorystore for Redis API
    "sqladmin.googleapis.com",             # Cloud SQL Admin API - required for Cloud SQL instances
    "cloudbuild.googleapis.com",           # Cloud Build API - required for App Engine deployments
    "secretmanager.googleapis.com",        # Secret Manager API - required for storing secrets
    "artifactregistry.googleapis.com",     # Artifact Registry API - required for storing Docker images
    "documentai.googleapis.com",           # Document AI API - required for document processing
    "datastore.googleapis.com",            # Cloud Datastore API - required for Datastore
    "aiplatform.googleapis.com",           # Vertex AI API - required for Vertex AI models
    "firestore.googleapis.com",            # Firestore API - required for Firestore databases
    "apigateway.googleapis.com",           # API Gateway API - required for API Gateway
    "servicemanagement.googleapis.com",    # Service Management API - required for service management
    "servicecontrol.googleapis.com",       # Service Control API - required for service control
    "cloudkms.googleapis.com",             # Cloud KMS API - required for Key Management Service
    "cloudresourcemanager.googleapis.com", # Cloud Resource Manager API - required for project metadata
  ]
}

# Time delay to ensure APIs are fully enabled
resource "time_sleep" "wait_for_apis" {
  depends_on = [module.api_resources]

  create_duration = "60s"
}
