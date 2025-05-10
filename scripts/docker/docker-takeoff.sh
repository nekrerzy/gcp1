#!/bin/bash

################################################################################
# GCP Deployment Docker Compose Wrapper
#
# This script uses Docker Compose to run the takeoff.sh script with persistent
# volumes for configuration and credentials.
################################################################################

set -e

# Script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." &> /dev/null && pwd)

# Docker image and service name
DOCKER_IMAGE="gcp-takeoff:latest"
DOCKER_SERVICE="gcp-takeoff"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_step() {
  echo -e "\n${BLUE}[STEP]${NC} $*"
}

# Check if Docker and Docker Compose are installed
check_docker() {
  log_step "Checking if Docker is installed"
  
  if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    log_info "Please install Docker from https://docs.docker.com/get-docker/"
    exit 1
  fi
  
  log_info "Docker is installed"
  
  # Check for docker compose
  if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
  elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
  else
    log_error "Docker Compose is not installed"
    log_info "Please install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
  fi
  
  log_info "Using Docker Compose command: ${COMPOSE_CMD}"
}

# Build the Docker image if it doesn't exist
build_docker_image() {
  log_step "Building Docker image"
  
  # Export REPO_ROOT for docker-compose.yml
  export REPO_ROOT
  
  # Build the image
  ${COMPOSE_CMD} -f "${SCRIPT_DIR}/docker-compose.yml" build
  
  log_info "Docker image built successfully"
}

# Run the container using Docker Compose
run_docker_container() {
  log_step "Running takeoff.sh with Docker Compose"
  
  # Export REPO_ROOT for docker-compose.yml
  export REPO_ROOT
  
  # Run the container
  ${COMPOSE_CMD} -f "${SCRIPT_DIR}/docker-compose.yml" run --rm ${DOCKER_SERVICE} "$@"
}

# Main function
main() {
  log_info "GCP Deployment Docker Compose Wrapper"
  
  # Check prerequisites
  check_docker
  
  # Build the image
  build_docker_image
  
  # Run the container
  run_docker_container "$@"
  
  log_info "GCP Deployment script execution completed"
}

# Execute main
main "$@"