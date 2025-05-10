# GCP Infrastructure Networking Guide

## Introduction

This guide explains the networking configuration options available in the Google Cloud Platform (GCP) Infrastructure as Code (IaC) solution and how they affect each service. The infrastructure is designed to provide secure, scalable connectivity between services while maintaining proper isolation and controlled access to Google Cloud resources.

The networking infrastructure uses Terraform as Infrastructure as Code (IaC), ensuring consistency, repeatability, and version control of our network configurations. This approach allows for easy auditing of changes and simplified management of network resources across environments.

## Networking Setup

This infrastructure is designed with a new VPC Network setup that includes:

- **App Subnet**: A dedicated subnet that hosts application services like GKE and other workloads (`10.10.0.0/20`)
- **Firewall Rules**: Appropriate rules to control inbound and outbound traffic
- **Cloud NAT**: Configuration for outbound connectivity from private instances
- **Private Service Access**: Secure connectivity for Google managed services

This guide focuses on the initial setup of a new networking infrastructure. Additional options for leveraging existing networks or deploying without network isolation may be added in future versions.

## Resource Networking Configuration

| Resource | Network Configuration |
|----------|----------------------|
| GKE Autopilot | ✓ VPC-native networking with private node option |
| Cloud SQL | ✓ Private IP only configuration |
| Artifact Registry | ✓ Private access via Private Google Access |
| Cloud Storage | ✓ Private access via Private Google Access |
| Document AI | ✓ Private access via VPC SC*  |
| Firestore | ✓ Private access via VPC SC*  |
| Vertex AI | ✓ Private endpoint with VPC attachment |

*VPC SC = VPC Service Controls

## Network Configuration Details

### VPC Network Configuration
- **VPC-native GKE**: GKE cluster configured with VPC-native networking for optimal IP usage and network performance
- **Private Service Access**: Used for Cloud SQL and other Google managed services through secure private connectivity
- **Firewall Rules**: Applied to control traffic with appropriate rules for security
- **Cloud NAT**: Configured for outbound internet access from private instances
- **Private Google Access**: Enabled for secure access to Google APIs without traversing the public internet

## Firewall Rules

When creating a new network, the following firewall rules are applied:

| Rule Name | Direction | Priority | Description |
|-----------|-----------|----------|-------------|
| **allow-internal** | INGRESS | 1000 | Allow internal traffic between VPC resources |
| **allow-health-checks** | INGRESS | 1000 | Allow health checks from Google Cloud |

## Service Network Configuration Details

| Service | Network Configuration |
|---------|----------------------|
| **GKE Autopilot** | • Private nodes enabled<br>• VPC-native networking for optimized IP management<br>• Workload Identity for secure service authentication<br>• Master authorized networks for controlled cluster access<br>• Optional private control plane for enhanced security |
| **Cloud SQL** | • Private IP only configuration (no public IP)<br>• Connected through VPC peering for secure access<br>• Accessible only from resources within the VPC<br>• Private path for Google Cloud services enabled |
| **Artifact Registry** | • Private access via Private Google Access<br>• Service account authentication<br>• IAM permissions for controlled access |
| **Cloud Storage** | • Private access via Private Google Access<br>• Service account authentication<br>• IAM and bucket permissions for access control |
| **Document AI** | • Private access via VPC Service Controls <br>• Service account authentication<br>• IAM permissions for processing access |
| **Firestore** | • Private access via VPC Service Controls <br>• Service account authentication<br>• IAM permissions for database access |
| **Vertex AI** | • Private endpoint enabled<br>• Network attached to VPC for secure access<br>• Public endpoint disabled for enhanced security |


## Private Access Methods

### Private Service Access
Used for:
- Cloud SQL
- Vertex AI RAY ( If enabled)
- Other services that require VPC peering

Configuration:
```hcl
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-service-access"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = module.networking.network_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = module.networking.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}
```

### Private Google Access
Used for:
- Cloud Storage
- Artifact Registry
- Google APIs

Configuration:
```hcl
resource "google_compute_subnetwork" "subnet" {
  name          = "app-subnet"
  ip_cidr_range = "10.10.0.0/20"
  network       = google_compute_network.vpc_network.self_link
  region        = "us-central1"
  
  private_ip_google_access = true
}
```

### VPC Service Controls
Used for:
- Document AI
- Firestore
- Vertex AI

Configuration requires a separate perimeter setup through the Google Cloud Console or additional Terraform resources.

## Troubleshooting

### Common Issues with Private Networking

1. **Private Service Access Issues**:
   - Ensure the peering connection is established
   - Verify IP range allocation is sufficient
   - Check for overlapping IP ranges

2. **GKE Connectivity Issues**:
   - Verify firewall rules allow required traffic
   - Check master authorized networks configuration
   - Ensure private nodes can access Google APIs

3. **Cloud SQL Access Problems**:
   - Verify private service access is correctly configured
   - Check that applications are using private IP for connection
   - Ensure service accounts have proper permissions

4. **Vertex AI Connectivity**:
   - Ensure network attachment is properly configured
   - Verify public endpoint is disabled as expected
   - Check service account permissions

5. **Troubleshooting Commands**:
   ```bash
   # Check VPC peering connections
   gcloud compute networks peerings list --network=NETWORK_NAME
   
   # Verify Cloud SQL instances have private IP
   gcloud sql instances describe INSTANCE_NAME | grep "ipAddress"
   
   # Check GKE cluster networking
   gcloud container clusters describe CLUSTER_NAME --zone=ZONE | grep -A 10 "networkConfig"
   
   # Inspect firewall rules
   gcloud compute firewall-rules list --filter="network:NETWORK_NAME"
   ```