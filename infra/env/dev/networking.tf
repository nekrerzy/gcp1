module "networking" {
  source = "../../modules/networking"

  project_id = var.project_id

  # Network configuration - now using GitHub variables
  network_option       = var.network_option
  network_name         = var.network_option == "create_new" ? "vpc-${var.project_id}-${var.environment}-${var.unique_suffix}" : ""
  existing_vpc_name    = var.network_option == "use_existing" ? var.existing_vpc_name : ""
  existing_subnet_name = var.network_option == "use_existing" ? var.existing_subnet_name : ""

  # These resources are only created when network_option is "create_new"
  subnets = [
    {
      name             = "app-subnet-${var.environment}-${var.unique_suffix}"
      ip_cidr_range    = "10.10.0.0/20"
      region           = var.region
      secondary_ranges = []
    }
  ]

  # Firewall rules
  firewall_rules = [
    {
      name        = "allow-internal-${var.project_id}-${var.environment}-${var.unique_suffix}"
      direction   = "INGRESS"
      priority    = 1000
      description = "Allow internal traffic between VPC resources"
      ranges      = ["10.10.0.0/16"]
      allow = [
        {
          protocol = "tcp"
          ports    = ["0-65535"]
        },
        {
          protocol = "udp"
          ports    = ["0-65535"]
        },
        {
          protocol = "icmp"
          ports    = []
        }
      ]
      deny                    = []
      target_tags             = []
      source_tags             = []
      source_service_accounts = []
      target_service_accounts = []
    },
    {
      name        = "allow-health-checks-${var.project_id}-${var.environment}-${var.unique_suffix}"
      direction   = "INGRESS"
      priority    = 1000
      description = "Allow health checks from Google Cloud"
      ranges      = ["35.191.0.0/16", "130.211.0.0/22"]
      allow = [
        {
          protocol = "tcp"
          ports    = ["80", "443"]
        }
      ]
      deny                    = []
      target_tags             = ["http-server", "https-server"]
      source_tags             = []
      source_service_accounts = []
      target_service_accounts = []
    }
  ]

  nat_router_name = "nat-router-${var.project_id}-${var.environment}-${var.unique_suffix}"
  nat_name        = "nat-config-${var.project_id}-${var.environment}-${var.unique_suffix}"

  region = var.region

  # Dependencies on API enablement
  depends_on = [
    module.api_resources
  ]
}


# Private service access address allocation - works for both scenarios
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-service-access-${var.project_id}-${var.environment}-${var.unique_suffix}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = module.networking.network_id
  address       = split("/", var.service_networking_range)[0]

  depends_on = [module.networking]
}

# Create the private connection to Google services - works for both scenarios
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = module.networking.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  deletion_policy         = "ABANDON"

  depends_on = [
    google_compute_global_address.private_ip_address
  ]
}
