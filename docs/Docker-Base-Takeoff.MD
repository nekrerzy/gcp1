# Docker-based GCP Deployment Guide

## Introduction

This guide explains how to use our Docker Compose solution for deploying applications to Google Cloud Platform (GCP). This containerized approach solves common deployment issues and provides a consistent environment across different development platforms (Linux, macOS, and Windows/WSL).

### What is this solution?

The `docker-takeoff.sh` script is a containerized wrapper around our GCP deployment script (`takeoff.sh`). It handles all the dependencies, authentication, and permissions in a Docker environment, making deployment simpler and more reliable.

### Key Benefits

- **Cross-platform compatibility**: Works the same on Linux, macOS, and Windows (WSL)
- **Persistent authentication**: You only need to log in once with GitHub and GCP
- **No dependency headaches**: All required tools are pre-installed in the container
- **No permission issues**: Avoids common file permission problems in WSL
- **Isolated environment**: Keeps deployment tooling separate from your local machine

## Prerequisites

- Docker installed on your machine ([Install Docker](https://docs.docker.com/get-docker/))
- Docker Compose installed ([Install Docker Compose](https://docs.docker.com/compose/install/))
- Git (to clone the repository)
- A GCP account
- A GitHub account and access to the repository

## Installation

1. Locate the repository:
   ```bash
   
   cd <repository-directory>
   ```

2. Navigate to the Docker script directory:
   ```bash
   cd scripts/docker
   ```

3. Make the wrapper script executable:
   ```bash
   chmod +x docker-takeoff.sh
   ```

## Usage

### Basic Usage

Run the deployment script with:

```bash
./scripts/docker/docker-takeoff.sh
```

The script will:
1. Build the Docker image (if not already built)
2. Start the container with properly mounted volumes
3. Run the deployment process
4. Store your authentication credentials for future runs

### First-time Setup

The first time you run the script, you will be prompted to:

1. **Authenticate with GitHub**: A browser window will open for GitHub authentication
2. **Authenticate with GCP**: You'll need to authorize the Google Cloud SDK
3. **Select or create a GCP project**
4. **Choose networking options** (VPC, subnet)

Your authentication will be stored in Docker volumes, so you won't need to repeat this process on subsequent runs.

### Passing Arguments

You can pass arguments to the underlying deployment script:

```bash
./scripts/docker/docker-takeoff.sh --some-option
```

## How It Works

### Component Overview

This solution consists of three main files:

1. **`docker-compose.yml`**: Defines the services, volumes, and configuration for running the deployment script
2. **`Dockerfile`**: Sets up the container environment with all required dependencies
3. **`docker-takeoff.sh`**: Wrapper script that handles Docker Compose execution

### Persistent Data with Docker Volumes

The solution uses four Docker volumes to maintain state between runs:

- **`gcp-takeoff-config`**: Stores the takeoff_config.yaml and other generated files
- **`gcloud-config`**: Stores Google Cloud SDK authentication
- **`github-config`**: Stores GitHub CLI authentication
- **`ssh-config`**: Stores SSH keys and configuration

This means you don't have to re-authenticate with GCP or GitHub every time you run the script.

## Troubleshooting

### Common Issues

#### Docker Not Running
```
Error: Cannot connect to the Docker daemon
```
**Solution**: Start the Docker service on your machine:
```bash
sudo systemctl start docker  # Linux
# On macOS, start Docker Desktop
```

#### Permission Denied Error
If you see permission errors when the container tries to access files:

**Solution**: Make sure you're running from the repository root or update the `REPO_ROOT` path in the script.

#### Authentication Issues
If you experience problems with GCP or GitHub authentication:

**Solution**: Remove the volumes and try again:
```bash
docker volume rm gcp-takeoff-config gcloud-config github-config ssh-config
```

## FAQ

### Does this work on Windows?
Yes, it works on Windows using WSL (Windows Subsystem for Linux).

### Will I need to re-authenticate every time?
No, authentication is stored in persistent Docker volumes.

### How do I update my GCP credentials?
Run the script again and choose to authenticate with different credentials when prompted.

### Where are my GCP and GitHub credentials stored?
In Docker volumes, isolated from your host machine.

### Is this secure?
Yes, your credentials are stored in Docker volumes which are more isolated than files on your host system.

