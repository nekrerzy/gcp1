# Takeoff Script Guide

The `takeoff.sh` script provides a guided deployment experience for setting up the GCP GenAI Platform. This document explains how to use the script and what each step does.

## Overview

The takeoff script automates these key tasks:

1. Installing required dependencies
2. Authenticating with GitHub and GCP
3. Setting up your GCP project
4. Configuring networking (VPC and subnets)
5. Setting up Terraform state storage
6. Configuring GitHub Actions integration with GCP
7. Deploying infrastructure and applications

## Prerequisites

Before running the script, you need:

- A GitHub account with access to this repository
- A Google account with full permission to create/access GCP projects
- Basic familiarity with GCP and Terraform concepts (Recommended)

## Running the Script

```bash
# Make the script executable
chmod +x ./scripts/takeoff.sh

# Run the script
./scripts/takeoff.sh
```

## Step-by-Step Process

### 1. Dependencies Check and Installation

The script checks for and installs these required tools:

- Google Cloud SDK (`gcloud`)
- GitHub CLI (`gh`)
- YAML processor (`yq`)
- JSON processor (`jq`)

If any dependency is missing, the script will install it.

### 2. GitHub Authentication

- Check if you're already authenticated with GitHub
- If not, prompt you to log in via `gh auth login`
- Retrieve your repository information
- Set up the GitHub token for Actions workflows

### 3. GCP Authentication

- Check if you're already authenticated with GCP
- If not, prompt you to log in via `gcloud auth login`
- Set up Application Default Credentials
- Let you select an existing project or create a new one

### 4. VPC Network Selection

You can choose to:
- Use an existing VPC network in your GCP project
- Let Terraform create a new VPC network

If using an existing VPC, the script scans available networks and lets you select one.

### 5. Subnet Selection

If you selected an existing VPC, you can use an existing subnet within that VPC, if you choose to create a new VPC, the script will create a new subnet.

### 6. Terraform Storage Setup

The script sets up a Cloud Storage bucket for Terraform state with:
- Proper naming based on your repository
- Versioning enabled
- Lifecycle management rules

### 7. Service Account Creation

A service account is created for GitHub Actions with:
- Permissions to deploy resources
- Workload Identity Federation for secure authentication
- GitHub repository variables for CI/CD integration

### 8. Configuration Generation

The script creates a configuration YAML file with:
- GCP project details
- Region and zone settings
- Network configuration
- GitHub repository information

### 9. GitHub Actions Setup

The script configures GitHub Actions by:
- Setting repository variables for GCP project details
- Setting up Workload Identity Federation
- Adding secrets for secure authentication

### 10. Workflow Execution

Finally, the script offers to:
- Run the infrastructure deployment workflow
- Monitor the workflow progress
- Run the application deployment workflow
- Monitor the application deployment progress

## Configuration File

The script generates a `takeoff_config.yaml` file with your settings:

```yaml
gcp:
  project_id: "your-project-id"
  region: "us-central1"
  zone: "us-central1-a"

github:
  repo_name: "your-username/your-repo"

environment:
  networking_option: "create_new"
  vpc_name: "tf_created_vpc"
  subnet_name: ""
  labels:
    managed-by: "terraform"
    environment: "development"
    team: "platform"
```

## Troubleshooting

### Authentication Issues

If you encounter GitHub authentication issues:
- Run `gh auth login` manually
- Check your GitHub token permissions

If you encounter GCP authentication issues:
- Run `gcloud auth login` manually
- Ensure you have proper permissions on the GCP project

### Network Configuration

If VPC/subnet scanning fails:
- Ensure you have the Compute Engine API enabled
- Verify you have proper permissions in GCP to view network resources

### GitHub Actions Workflow Issues

If the workflow doesn't start:
- Check if the `.github/workflows` directory exists in your repository and contains the workflow files
- Verify GitHub Actions is enabled for your repository

## Next Steps

After running the takeoff script:

1. Check your GitHub repository's Actions tab to monitor workflow progress
2. Review the generated infrastructure in the GCP Console
3. Access your deployed application once the workflows complete
4. Make any necessary customizations to the infrastructure or application code if needed