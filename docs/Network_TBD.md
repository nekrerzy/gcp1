# VPC Network Configuration Documentation

## Introduction

This document provides a comprehensive overview of the Google Cloud Platform (GCP) Virtual Private Cloud (VPC) network infrastructure deployed for our development environment. The network has been designed to provide secure, scalable, and reliable connectivity for application services while maintaining proper isolation and controlled access to Google Cloud services.

The infrastructure is deployed using Terraform as Infrastructure as Code (IaC), which ensures consistency, repeatability, and version control of our network configurations. This approach allows for easy auditing of changes and simplified management of network resources across environments.

The VPC network serves as the foundation for our cloud resources, enabling private communication between services, controlled internet access, and secure connectivity to Google managed services. This document details the current configuration, explains key components, and provides guidance for troubleshooting and future expansion.

## Current Setup

1. **VPC Network**
   - Name: Based on `network_name`
   - Auto-create subnets: Defined by `auto_create_subnetworks` in Terraform files.

2. **Subnets**
   - Primary Subnet: `app-subnet`
     - CIDR Range: `10.10.0.0/20`
     - Region: `us-central1`
     - Private Google API access: Enabled

3. **Firewall Rules**
   - **allow-internal**
     - Direction: INGRESS
     - Priority: 1000
     - Description: "Allow internal traffic between VPC resources"
     - Source ranges: ["10.10.0.0/16"]
     - Allowed protocols:
       - TCP ports: 0-65535
       - UDP ports: 0-65535
       - ICMP
     
   - **allow-health-checks**
     - Direction: INGRESS
     - Priority: 1000
     - Description: "Allow health checks from Google Cloud"
     - Source ranges: ["35.191.0.0/16", "130.211.0.0/22"]
     - Allowed protocols:
       - TCP ports: 80, 443
     - Target tags: ["http-server", "https-server"]

4. **Cloud NAT**
   - Router: `dev-nat-router`
   - NAT Gateway: `dev-nat-config`
   - Settings:
     - TCP established idle timeout: 1200 seconds
     - TCP transitory idle timeout: 30 seconds
     - UDP idle timeout: 30 seconds
     - Endpoint independent mapping: Enabled

5. **Service Networking**
   - Private IP Address: `private-service-access`
   - Purpose: VPC_PEERING
   - Address Type: INTERNAL
   - Prefix Length: 20
   - Address Range: Based on `var.service_networking_range`
   - Connected Service: `servicenetworking.googleapis.com`
   - Deletion Policy: ABANDON

  """
  Note:
  - The prefix length must be set to a minimum of 20 to enable Vertex AI RAY to create clusters connected to the VPC.
  - Any prefix length above 20 will prevent integration with the VPC, so ensure the value is carefully chosen.
  """

## Private Access Configuration

### Private Service Access

A private connection has been established between the VPC network and Google services:

```hcl
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = module.networking.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  
}
```

This allows Google services like Cloud SQL, Memorystore, and others to be accessed using private IP addresses within the VPC.

## Internet Access

1. **Default Internet Route**
   - Name: `[network_name]-internet-route`
   - Destination: `0.0.0.0/0`
   - Next hop: default-internet-gateway
   - Priority: 1000

2. **Cloud NAT for Outbound Connectivity**
   - Provides outbound internet access for resources without public IP addresses
   - Configuration as described above

## Communication Between Resources

### Internal Communication

All resources within the VPC can communicate with each other through:

- The `allow-internal` firewall rule that permits all traffic between resources in the 10.10.0.0/16 range
- This includes TCP, UDP, and ICMP protocols

### Accessing Google Services

Resources in the VPC can access Google APIs and services using private IP addresses through:

- `private_ip_google_access = true` setting on subnets
- The private service connection established for service networking

## Security Considerations

1. **Network Isolation**
   - The VPC provides network isolation for resources
   - Only specified traffic is allowed through firewall rules

2. **Private Google Access**
   - Resources can access Google APIs without going through the public internet
   - Reduces exposure to internet-based threats

3. **Health Check Access**
   - Only Google Cloud health check systems can access HTTP/HTTPS endpoints
   - Limited to necessary ports (80, 443)

## Troubleshooting

1. **Connectivity Issues**
   - Check firewall rules:
     ```bash
     gcloud compute firewall-rules list --filter="network:var.network_name"
     ```
   - Verify NAT configuration:
     ```bash
     gcloud compute routers nats describe dev-nat-config --router=dev-nat-router --region=var.region
     ```

2. **Service Access Problems**
   - Verify private service connection:
     ```bash
     gcloud services vpc-peerings list --network=var.network_name
     ```
   - Check private IP allocation:
     ```bash
     gcloud compute addresses describe private-service-access --global
     ```

3. **DNS Resolution**
   - Default DNS servers (8.8.8.8 and 8.8.4.4) are configured for the network

## GKE Autopilot Networking

1. **VPC-Native Networking with GKE Autopilot**
   - GKE Autopilot automatically provisions and manages its own secondary IP ranges behind the scenes
   - These secondary ranges provide:
     - Pod IP addressing (similar to what would be manually defined as "pod-range")
     - Service IP addressing (similar to what would be manually defined as "service-range")
   - The absence of explicit secondary range definitions in Terraform is deliberate:
     - GKE Autopilot manages IP allocation automatically
     - Google Cloud automatically creates and manages the necessary peering connections
     - This reduces operational complexity while maintaining VPC-native networking benefits

2. **Important Considerations**
   - When planning IP address space, be aware that GKE Autopilot still consumes IP address space from your VPC
   - The auto-allocated ranges are not explicitly visible in your Terraform but will appear in the Google Cloud Console
   - These ranges are automatically protected by GKE's control plane

2. **Additional Subnets**
   - A `gcloud-services` subnet is prepared in the configuration (commented)
   - Can be enabled to separate Google Cloud service resources

3. **Network Logging**
   - Flow logs are currently commented out but can be enabled for improved visibility
   - Would provide detailed network traffic analysis with:
     - 5-second aggregation intervals
     - 50% flow sampling
     - Complete metadata