# Data sources for existing VPC and subnet
data "google_compute_network" "existing_vpc" {
  count   = var.network_option == "use_existing" ? 1 : 0
  name    = var.existing_vpc_name
  project = var.project_id
}

data "google_compute_subnetwork" "existing_subnet" {
  count   = var.network_option == "use_existing" ? 1 : 0
  name    = var.existing_subnet_name
  region  = var.region
  project = var.project_id
}

# Create the VPC network (conditionally)
resource "google_compute_network" "vpc_network" {
  count                   = var.network_option == "create_new" ? 1 : 0
  name                    = var.network_name
  auto_create_subnetworks = var.auto_create_subnetworks
  routing_mode            = var.routing_mode
  project                 = var.project_id

  delete_default_routes_on_create = false

  description = "VPC Network for ${var.network_name}"
}

# Create subnets within the VPC network (conditionally)
resource "google_compute_subnetwork" "subnets" {
  count = var.network_option == "create_new" ? length(var.subnets) : 0

  name          = var.subnets[count.index].name
  ip_cidr_range = var.subnets[count.index].ip_cidr_range
  region        = var.subnets[count.index].region
  network       = google_compute_network.vpc_network[0].id
  project       = var.project_id

  # Instances in this subnet can access Google APIs and services using private IP addresses
  private_ip_google_access = true

  # Log configuration settings - important for security and debugging
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  # Set up secondary IP ranges for GKE pods and services if defined
  dynamic "secondary_ip_range" {
    for_each = var.subnets[count.index].secondary_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}

# Create firewall rules for the network (conditionally)
resource "google_compute_firewall" "rules" {
  count = var.network_option == "create_new" ? length(var.firewall_rules) : 0

  name        = var.firewall_rules[count.index].name
  network     = google_compute_network.vpc_network[0].name
  project     = var.project_id
  description = var.firewall_rules[count.index].description
  direction   = var.firewall_rules[count.index].direction
  priority    = var.firewall_rules[count.index].priority

  source_ranges      = var.firewall_rules[count.index].direction == "INGRESS" ? var.firewall_rules[count.index].ranges : null
  destination_ranges = var.firewall_rules[count.index].direction == "EGRESS" ? var.firewall_rules[count.index].ranges : null

  target_tags = length(var.firewall_rules[count.index].target_tags) > 0 ? var.firewall_rules[count.index].target_tags : null
  source_tags = length(var.firewall_rules[count.index].source_tags) > 0 ? var.firewall_rules[count.index].source_tags : null

  dynamic "allow" {
    for_each = var.firewall_rules[count.index].allow
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  dynamic "deny" {
    for_each = var.firewall_rules[count.index].deny
    content {
      protocol = deny.value.protocol
      ports    = deny.value.ports
    }
  }
}

# Cloud NAT for outbound connectivity (conditionally)
resource "google_compute_router" "router" {
  count   = var.network_option == "create_new" ? 1 : 0
  name    = var.nat_router_name
  region  = var.region
  network = google_compute_network.vpc_network[0].id
  project = var.project_id

  description = "Router for Cloud NAT in ${var.network_name}"

  bgp {
    asn = 64514 # Private ASN for the router
  }
}

resource "google_compute_router_nat" "nat" {
  count   = var.network_option == "create_new" ? 1 : 0
  name    = var.nat_name
  router  = google_compute_router.router[0].name
  region  = var.region
  project = var.project_id

  nat_ip_allocate_option             = var.nat_ip_allocate_option
  source_subnetwork_ip_ranges_to_nat = var.nat_source_subnetwork_ip_ranges_to_nat

  # NAT timeouts for better performance
  tcp_established_idle_timeout_sec = 1200
  tcp_transitory_idle_timeout_sec  = 30
  udp_idle_timeout_sec             = 30

  enable_endpoint_independent_mapping = true
}

# Add default internet route (conditionally)
resource "google_compute_route" "internet_route" {
  count            = var.network_option == "create_new" ? 1 : 0
  name             = "${var.network_name}-internet-route"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.vpc_network[0].name
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
  project          = var.project_id
  description      = "Default route to the Internet"
}

# Create a DNS policy for the VPC network (conditionally)
resource "google_dns_policy" "default" {
  count = var.network_option == "create_new" ? 1 : 0
  name  = "${var.network_name}-dns-policy"

  networks {
    network_url = google_compute_network.vpc_network[0].id
  }

  # Google DNS servers
  alternative_name_server_config {
    target_name_servers {
      ipv4_address = "8.8.8.8"
    }
    target_name_servers {
      ipv4_address = "8.8.4.4"
    }
  }

  project = var.project_id
}
