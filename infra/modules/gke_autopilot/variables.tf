variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
}

variable "region" {
  description = "The region where the GKE cluster will be created"
  type        = string
}

variable "zone" {
  description = "The zone where the GKE cluster will be created (if not regional)"
  type        = string
  default     = ""
}

variable "regional" {
  description = "Whether the GKE cluster should be regional or zonal"
  type        = bool
  default     = false
}

variable "network" {
  description = "The VPC network to host the cluster"
  type        = string
}

variable "subnetwork" {
  description = "The subnetwork to host the cluster"
  type        = string
}

variable "pod_range_name" {
  description = "The name of the secondary IP range for pods"
  type        = string
}

variable "service_range_name" {
  description = "The name of the secondary IP range for services"
  type        = string
}

variable "private_cluster" {
  description = "Whether nodes have internal IP addresses only"
  type        = bool
  default     = true
}

variable "private_endpoint" {
  description = "Whether the master is accessible via internal IP only"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "The IP range for the master network"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "List of master authorized networks"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "release_channel" {
  description = "Release channel for GKE versions"
  type        = string
  default     = "REGULAR"
}

variable "maintenance_start_time" {
  description = "Start time for the daily maintenance window"
  type        = string
  default     = "03:00"
}

variable "service_account_email" {
  description = "The service account email to use for nodes"
  type        = string
}