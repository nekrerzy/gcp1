# GCP GenAI Infrastructure as Code Guide

This repository contains Infrastructure as Code (IaC) templates using Terraform to help you deploy and manage your web application in GCP with GenAI capabilities. This guide is designed for developers with 1-2 years of software experience who want to host their web applications in GCP.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.0.0-blueviolet)
![GCP](https://img.shields.io/badge/gcp-in_progress-green)


## Cloud Architecture

![Cloud Architecture](/docs/Cloud.png)

## Overview

The template implements a health dashboard application that monitors GCP services commonly used for GenAI applications:

- Vertex AI (Gemini models and Vector Search)
- Document AI (Document processing)
- Cloud Storage (Blob storage)
- Firestore Database (NoSQL)
- Cloud SQL (PostgreSQL)
- Secret Manager (Sensitive data management)

## Repository Structure

```
├── app/                   # Sample Application code
│   ├── backend/           # FastAPI backend service
│   ├── frontend/          # React frontend application
│   └── helmcharts/        # Helm charts for Kubernetes deployment
├── docs/                  # Documentation
├── infra/                 # Terraform infrastructure code
│   ├── env/               # Environment-specific configurations
│   └── modules/           # Reusable Terraform modules
└── scripts/               # Deployment and utility scripts
    └── takeoff.sh         # Guided deployment script
```

## Getting Started

The quickest way to get started is to use the included `takeoff.sh` script, which guides you through:

1. Setting up your local environment
2. GitHub authentication and repository selection
3. GCP project creation or selection
4. Network configuration (VPC and subnets)
5. Terraform state storage setup
6. CI/CD integration with GitHub Actions
7. Infrastructure deployment

```bash
# Run the takeoff script
chmod +x ./scripts/takeoff.sh
./scripts/takeoff.sh
```

## Infrastructure Components

The infrastructure is defined as code using Terraform modules:

- **GKE Autopilot** - Managed Kubernetes environment
- **Networking** - VPC, subnets, and firewall rules
- **Artifact Registry** - Container storage
- **Cloud SQL** - PostgreSQL database
- **Document AI** - Document processing 
- **Firestore** - NoSQL database
- **Service Accounts** - Identity and access management
- **Storage** - Cloud Storage buckets
- **Vertex AI** - AI capabilities
- **Secret Manager** - Sensitive data management

## Application Architecture

The Sample application consists of:

- **Frontend**: React dashboard for service health monitoring 
- **Backend**: FastAPI service that connects to GCP services
- **API Gateway**: ESPv2 (Cloud Endpoints) for API protection
- **Kubernetes Deployment**: Managed with Helm charts

## Deployment Architecture

The application is deployed to GKE Autopilot with:

- Public frontend with global static IP ( A domain name can be easily mapped to the static IP and use by the frontend ingress)
- Private backend services   
- Protected backend API
- Workload Identity for service authentication
- Separate namespaces for isolation

## CI/CD Integration

The repository includes CI/CD integration with GitHub Actions for:

1. Infrastructure provisioning with Terraform
2. App deployment with Container builds and deployment process
3. Optional Cleanup of resources with Terraform destroy

## Next Steps

1. Review the documentation in the `docs/` directory
2. Customize the template for your specific use case
3. Run the takeoff script to initialize your deployment


## Security Notes

This template implements security best practices:

- Workload Identity Federation instead of service account keys
- Private GKE clusters
- Secret management with Google Secret Manager
- Network isolation with VPC

## Additional Documentation

Detailed documentation is available in the `docs/` directory:

- Developer connection guides
- Networking setup
- API protection
- Terraform Infrastructure Guide
- Takeoff script Guide

