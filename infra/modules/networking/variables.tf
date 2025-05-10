variable "network_option" {
  description = "Option to create a new VPC or use an existing one (create_new or use_existing)"
  type        = string
  default     = "create_new"
}

variable "existing_vpc_name" {
  description = "Name of existing VPC when network_option is use_existing"
  type        = string
  default     = ""
}

variable "existing_subnet_name" {
  description = "Name of existing subnet when network_option is use_existing"
  type        = string
  default     = ""
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region where resources will be created"
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnets" {
  description = "List of subnet configurations (name, cidr, region, secondary_ranges)"
  type = list(object({
    name          = string
    ip_cidr_range = string
    region        = string
    secondary_ranges = list(object({
      range_name    = string
      ip_cidr_range = string
    }))
  }))
  default = []
}

variable "auto_create_subnetworks" {
  description = "Whether to create auto-mode subnets"
  type        = bool
  default     = false
}

variable "routing_mode" {
  description = "The network routing mode (REGIONAL or GLOBAL)"
  type        = string
  default     = "REGIONAL"
}

variable "firewall_rules" {
  description = "List of firewall rules to create"
  type = list(object({
    name        = string
    direction   = string
    priority    = number
    description = string
    ranges      = list(string)
    allow = list(object({
      protocol = string
      ports    = list(string)
    }))
    deny = list(object({
      protocol = string
      ports    = list(string)
    }))
    target_tags             = list(string)
    source_tags             = list(string)
    source_service_accounts = list(string)
    target_service_accounts = list(string)
  }))
  default = []
}

variable "nat_router_name" {
  description = "Name of the Cloud NAT router"
  type        = string
}

variable "nat_name" {
  description = "Name of the Cloud NAT configuration"
  type        = string
}

variable "nat_ip_allocate_option" {
  description = "How external IPs should be allocated for the NAT (AUTO_ONLY or MANUAL_ONLY)"
  type        = string
  default     = "AUTO_ONLY"
}

variable "nat_source_subnetwork_ip_ranges_to_nat" {
  description = "How NAT should be configured per subnetwork (ALL_SUBNETWORKS_ALL_IP_RANGES, ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES, LIST_OF_SUBNETWORKS)"
  type        = string
  default     = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

variable "nat_log_config_enable" {
  description = "Whether to enable NAT logging"
  type        = bool
  default     = true
}

variable "nat_log_config_filter" {
  description = "Specifies the desired filtering of logs (ERRORS_ONLY, TRANSLATIONS_ONLY, ALL)"
  type        = string
  default     = "ALL"
}
