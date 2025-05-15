# Terraform Infrastructure Guide

This guide explains the Terraform modules in this repository and how to customize them for your needs.

## Infrastructure Overview

The Terraform code in this repository creates:
- A Google Kubernetes Engine (GKE) Autopilot cluster
- Networking resources (VPC, subnets, firewall rules)
- Artifact Registry for storing container images
- Supporting GCP services (Cloud SQL, Firestore, Storage, etc.)

## Module Structure

```
infra/
├── modules/               # Reusable Terraform modules
│   ├── api_resources/     # Enables required Google Cloud APIs
│   ├── artifact_registry/ # Container registry
│   ├── cloud_sql/         # PostgreSQL database
│   ├── document_ai/       # Document processing
│   ├── firestore/         # NoSQL database
│   ├── gke_autopilot/     # Kubernetes cluster
│   ├── networking/        # VPC and network resources
│   ├── service_accounts/  # IAM configuration
│   ├── storage/           # Cloud Storage buckets
│   └── vertex_ai/         # AI services
└── env/                   # Environment configurations and modules calling
```

## Common Customizations Examples
This section provides examples of common customizations you might want to make to the Terraform modules.

### 1. Scaling Cloud SQL Resources

To increase the CPU and memory of your Cloud SQL instance, modify the `tier` parameter:

```hcl
# Original configuration
module "cloud_sql" {
  source        = "../modules/cloud_sql"
  project_id    = var.project_id
  region        = var.region
  instance_name = "genai-postgres"
  tier          = "db-g1-small"  # 1 vCPU, 1.7 GB RAM
}

# Scaled up configuration
module "cloud_sql" {
  source        = "../modules/cloud_sql"
  project_id    = var.project_id
  region        = var.region
  instance_name = "genai-postgres"
  tier          = "db-custom-4-16384"  # 4 vCPUs, 16 GB RAM
}
```

### 2. Adding Redis Cache

To add Redis to your deployment, you'll need to make these changes:

#### Step 1: Ensure Redis API is enabled
First, check if the Redis API is included in your api_resources module:

```hcl
# In infra/services/apis.tf
module "api_resources" {
  source     = "../modules/api_resources"
  project_id = var.project_id
  apis       = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "redis.googleapis.com",  # Make sure this is included
    # Other APIs...
  ]
}
```

#### Step 2: Create a Redis module
Create a new file `infra/modules/redis/main.tf`:

```hcl
resource "google_redis_instance" "cache" {
  name           = var.name
  tier           = var.tier
  memory_size_gb = var.memory_size_gb
  region         = var.region
  project        = var.project_id
  
  authorized_network = var.network_id
  connect_mode       = var.connect_mode
  
  redis_version     = var.redis_version
  display_name      = var.display_name
  
  labels = var.labels
}
```

#### Step 3: Add variables file
Create `infra/modules/redis/variables.tf`:

```hcl
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "name" {
  description = "The ID of the instance or a fully qualified identifier for the instance"
  type        = string
}

variable "region" {
  description = "The GCP region where the Redis instance will be created"
  type        = string
}

variable "tier" {
  description = "The service tier of the instance"
  type        = string
  default     = "BASIC"
}

variable "memory_size_gb" {
  description = "Redis memory size in GiB"
  type        = number
  default     = 1
}

variable "network_id" {
  description = "The full name of the network to connect the instance to"
  type        = string
}

variable "connect_mode" {
  description = "The connection mode of the Redis instance"
  type        = string
  default     = "DIRECT_PEERING"
}

variable "redis_version" {
  description = "The version of Redis software"
  type        = string
  default     = "REDIS_6_X"
}

variable "display_name" {
  description = "An arbitrary and optional user-provided name for the instance"
  type        = string
  default     = null
}

variable "labels" {
  description = "Resource labels to represent user provided metadata"
  type        = map(string)
  default     = {}
}
```

#### Step 4: Create outputs file
Create `infra/modules/redis/outputs.tf`:

```hcl
output "id" {
  description = "The Redis instance ID"
  value       = google_redis_instance.cache.id
}

output "host" {
  description = "The IP address of the Redis instance"
  value       = google_redis_instance.cache.host
}

output "port" {
  description = "The port number of the Redis instance"
  value       = google_redis_instance.cache.port
}

output "current_location_id" {
  description = "The current zone where the Redis endpoint is placed"
  value       = google_redis_instance.cache.current_location_id
}
```

#### Step 5: Use the module in your environment
Add `infra/services/redis.tf` file:

```hcl
module "redis" {
  source         = "../modules/redis"
  project_id     = var.project_id
  name           = "genai-redis"
  region         = var.region
  tier           = "STANDARD_HA"  # Use STANDARD_HA for high availability
  memory_size_gb = 5
  network_id     = module.networking.vpc_network_id
  connect_mode   = "PRIVATE_SERVICE_ACCESS"
  redis_version  = "REDIS_7_X"
  display_name   = "GenAI Redis Cache"
  
  labels = {
    environment = "dev"
    managed-by  = "terraform"
  }
}
```

#### Step 6: Add outputs to access Redis connection details
In your `infra/services/outputs.tf` file:

```hcl
output "redis_host" {
  description = "The Redis instance host"
  value       = module.redis.host
}

output "redis_port" {
  description = "The Redis instance port"
  value       = module.redis.port
}
```


### Using GitHub Actions to apply changes (Recommended)

To automate the deployment of your Terraform changes, you can use the existing GitHub Actions workflow. This workflow can be call manually or can up updated to trigger on specific events (e.g., push to main branch).


### You can also get all the most recent syntax and examples from the official Terraform documentation:
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
