
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.26.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.24.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.0-pre2"
    }
  }

  
  backend "gcs" { }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "kubernetes" {

  host                   = "https://${module.gke_autopilot.cluster_endpoint}"
  cluster_ca_certificate = module.gke_autopilot.cluster_ca_certificate


  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
    args        = ["--use_application_default_credentials"]
  }
}


provider "helm" {
  kubernetes {

    host                   = "https://${module.gke_autopilot.cluster_endpoint}"
    cluster_ca_certificate = module.gke_autopilot.cluster_ca_certificate
    exec {
      api_version = "client.authentication.k8s.io/v1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}



provider "time" {}

provider "random" {}