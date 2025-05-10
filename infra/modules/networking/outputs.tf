output "network_name" {
  description = "The name of the VPC network"
  value       = var.network_option == "create_new" ? google_compute_network.vpc_network[0].name : data.google_compute_network.existing_vpc[0].name
}

output "network_id" {
  description = "The ID of the VPC network"
  value       = var.network_option == "create_new" ? google_compute_network.vpc_network[0].id : data.google_compute_network.existing_vpc[0].id
}

output "network_self_link" {
  description = "The URI of the VPC network"
  value       = var.network_option == "create_new" ? google_compute_network.vpc_network[0].self_link : data.google_compute_network.existing_vpc[0].self_link
}

output "subnets_names" {
  description = "The names of subnets"
  value       = var.network_option == "create_new" ? [for subnet in google_compute_subnetwork.subnets : subnet.name] : [data.google_compute_subnetwork.existing_subnet[0].name]
}

output "subnets_ids" {
  description = "The IDs of subnets"
  value       = var.network_option == "create_new" ? [for subnet in google_compute_subnetwork.subnets : subnet.id] : [data.google_compute_subnetwork.existing_subnet[0].id]
}

output "subnets_self_links" {
  description = "The URIs of subnets"
  value       = var.network_option == "create_new" ? [for subnet in google_compute_subnetwork.subnets : subnet.self_link] : [data.google_compute_subnetwork.existing_subnet[0].self_link]
}

output "subnets_ips" {
  description = "The IP CIDR ranges of subnets"
  value       = var.network_option == "create_new" ? [for subnet in google_compute_subnetwork.subnets : subnet.ip_cidr_range] : [data.google_compute_subnetwork.existing_subnet[0].ip_cidr_range]
}

output "subnets_regions" {
  description = "The regions of subnets"
  value       = var.network_option == "create_new" ? [for subnet in google_compute_subnetwork.subnets : subnet.region] : [data.google_compute_subnetwork.existing_subnet[0].region]
}

output "subnets_secondary_ranges" {
  description = "The secondary IP ranges of subnets"
  value = var.network_option == "create_new" ? {
    for subnet in google_compute_subnetwork.subnets : subnet.name => {
      for secondary_range in subnet.secondary_ip_range : secondary_range.range_name => secondary_range.ip_cidr_range
    }
  } : {}
}

output "router_name" {
  description = "The name of the router created"
  value       = var.network_option == "create_new" ? (length(google_compute_router.router) > 0 ? google_compute_router.router[0].name : null) : null
}

output "router_id" {
  description = "The ID of the router created"
  value       = var.network_option == "create_new" ? (length(google_compute_router.router) > 0 ? google_compute_router.router[0].id : null) : null
}

output "nat_name" {
  description = "The name of the Cloud NAT created"
  value       = var.network_option == "create_new" ? (length(google_compute_router_nat.nat) > 0 ? google_compute_router_nat.nat[0].name : null) : null
}

output "nat_ip" {
  description = "The external IP addresses used by Cloud NAT"
  value       = var.network_option == "create_new" ? (length(google_compute_router_nat.nat) > 0 ? google_compute_router_nat.nat[0].nat_ips : null) : null
}

output "firewall_rules" {
  description = "The firewall rule details created"
  value = var.network_option == "create_new" ? {
    for rule in google_compute_firewall.rules : rule.name => {
      name        = rule.name
      id          = rule.id
      direction   = rule.direction
      priority    = rule.priority
      target_tags = rule.target_tags
    }
  } : {}
}
