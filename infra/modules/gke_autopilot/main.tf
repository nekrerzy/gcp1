
## Static IP addresses for GKE ingress Front and API

resource "google_compute_global_address" "frontend" {
  name         = "${var.cluster_name}-frontend-ip-${var.environment}"
  description  = "Global static IP address for Frontend GKE ingress"
  address_type = "EXTERNAL"
  project      = var.project_id
}

resource "google_compute_global_address" "api" {
  name         = "${var.cluster_name}-api-ip-${var.environment}"
  description  = "Global static IP address for API GKE ingress"
  address_type = "EXTERNAL"
  project      = var.project_id

}



###GKE CLUSTER

resource "google_container_cluster" "autopilot" {
  name     = var.cluster_name
  location = var.environment == "prod" ? var.region : var.zone
  project  = var.project_id


  # Enable Autopilot mode
  enable_autopilot = true

  # Networking configuration
  network             = var.network
  subnetwork          = var.subnetwork
  deletion_protection = var.environment == "prod" ? true : false


  # explicity set the service_account used by the GKE nodes to prevent the default service account from being used
  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = var.service_account_email
      oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    }
  }


  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }
  #IP allocation policy for pods and services
  ip_allocation_policy {


  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
  }

  control_plane_endpoints_config {

    dns_endpoint_config {
      allow_external_traffic = true
    }
  }

  node_config {
    gvnic {
      enabled = true
    }

    service_account = var.service_account_email

    reservation_affinity {
      consume_reservation_type = "NO_RESERVATION"
      values                   = []
    }
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }


  #Master authorized networks
  master_authorized_networks_config {}

  # Release channel for automatic upgrades
  release_channel {
    channel = var.release_channel
  }

  # Workload identity configuration
  workload_identity_config {

    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Maintenance policy
  maintenance_policy {

    daily_maintenance_window {
      start_time = var.maintenance_start_time
    }
  }


  networking_mode = "VPC_NATIVE"

  resource_labels = {
    project = var.project_id


  }

}
