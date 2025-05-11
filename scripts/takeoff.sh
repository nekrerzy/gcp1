#!/bin/bash

################################################################################
# GCP Deployment Script
# 
# A modular script for setting up and deploying to Google Cloud Platform
# with GitHub Actions integration and multiple environment support
################################################################################

set -e  # Exit on errors

###################### CONFIGURATION AND GLOBALS ###############################

SCRIPT_VERSION="2.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)
ENV_FILE="./.env"

# Default settings - used when GitHub variables don't exist
DEFAULT_GCP_REGION="us-central1"
DEFAULT_GCP_ZONE="us-central1-a"
DEFAULT_NETWORKING_OPTION="create_new"
DEFAULT_ENV="dev"

# User repository details - will be set after GitHub auth
USER_REPO_PATH=""
USER_REPO_URL=""
GCP_PROJECT=""

###################### LOGGING UTILITIES ######################################

# Optional log level control
LOG_LEVEL=${LOG_LEVEL:-"INFO"}  # ERROR, WARNING, INFO, DEBUG

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_error() { 
  [[ "$LOG_LEVEL" =~ ^(ERROR|WARNING|INFO|DEBUG)$ ]] && echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warning() { 
  [[ "$LOG_LEVEL" =~ ^(WARNING|INFO|DEBUG)$ ]] && echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_info() { 
  [[ "$LOG_LEVEL" =~ ^(INFO|DEBUG)$ ]] && echo -e "${GREEN}[INFO]${NC} $*"
}

log_debug() { 
  [[ "$LOG_LEVEL" =~ ^(DEBUG)$ ]] && echo -e "${BLUE}[DEBUG]${NC} $*"
}

log_step() {
  echo -e "\n${BLUE}[STEP]${NC} $*"
}

spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

###################### ERROR HANDLING #########################################

handle_error() {
  local line=$1
  local cmd=$2
  log_error "Failed at line $line: Command '$cmd' exited with status $?"
}

trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

cleanup() {
  log_debug "Performing cleanup..."
  # Remove temporary files
  rm -f /tmp/lifecycle.json 2>/dev/null || true
  rm -f /tmp/*-key.json 2>/dev/null || true
  # Any other cleanup tasks
}

trap cleanup EXIT

###################### ENVIRONMENT PLAN ######################################

display_script_overview() {
  cat << "EOT"
╔════════════════════════════════════════════════════════════════╗
║                  GCP DEPLOYMENT SCRIPT OVERVIEW                 ║
╚════════════════════════════════════════════════════════════════╝

  This script automates setting up a Google Cloud Platform (GCP) 
  deployment environment integrated with GitHub Actions.

  WHAT THIS SCRIPT WILL DO:
  
  1. Check and install required dependencies
  2. Authenticate with GitHub and set your repository
  3. Select or create a target environment (dev/staging/prod)
  4. Authenticate with GCP and select/create a project
  5. Select to use an existing VPC or create a new one
  6. Select to use an existing subnet or create a new one
  7. Set up Terraform state storage in GCP
  8. Configure GitHub Actions integration with GCP:
     - Create service account for GitHub Actions
     - Set up Workload Identity Federation (recommended)
     - Configure GitHub repository secrets and variables
  9. Trigger infrastructure deployment workflow
  10. Optionally deploy your application

  PREREQUISITES:
  - GitHub repository with all necessary files
  - A Google account with owner access to GCP
  - Basic understanding of GCP/Terraform resources (recommended)

  Press Ctrl+C at any time to cancel the process.
EOT

  echo
  read -e -p "Continue with setup? (Y/n): " continue_setup
  if [[ "$continue_setup" =~ ^[Nn]$ ]]; then
    log_info "Setup canceled"
    exit 0
  fi
  
  echo
}

###################### DEPENDENCY MANAGEMENT ##################################

get_os_type() {
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "windows"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  else
    echo "linux"
  fi
}

check_dependency() {
  local cmd=$1
  local install_msg=$2
  local install_cmd=$3
  local os_type=$(get_os_type)

  log_debug "Checking for $cmd..."
  if ! command -v "$cmd" &> /dev/null; then
    log_warning "$cmd not found. $install_msg"
    if [[ -n "$install_cmd" ]]; then
      eval "$install_cmd" & spinner $!
      # Verify installation
      if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd installation failed"
        return 1
      fi
    else
      return 1
    fi
  else
    log_debug "$cmd is installed"
  fi
  return 0
}

install_dependencies() {
  log_step "Checking dependencies"
  local os_type=$(get_os_type)
  local success=true

  # Check package manager first
  case "$os_type" in
    macos)
      check_dependency "brew" "Installing Homebrew..." \
        "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" \
        || success=false
      ;;
    windows)
      check_dependency "winget" "Please install App Installer from Microsoft Store" "" \
        || success=false
      ;;
    linux)
      if ! command -v apt-get &> /dev/null && ! command -v yum &> /dev/null; then
        log_warning "No recognized package manager found. You may need to install dependencies manually."
      fi
      ;;
  esac

  # Define dependency array
  declare -A dependencies
  
  # Format: [command_name]="install_message|install_function"
  dependencies["gcloud"]="Installing Google Cloud SDK...|install_gcloud"
  dependencies["gh"]="Installing GitHub CLI...|install_gh"
  dependencies["yq"]="Installing yq...|install_yq"
  dependencies["jq"]="Installing jq...|install_jq"
  
  
  # Check and install each dependency
  for cmd in "${!dependencies[@]}"; do
    IFS="|" read -r message install_function <<< "${dependencies[$cmd]}"
    
    if ! command -v "$cmd" &> /dev/null; then
      log_info "$message"
      $install_function || success=false
    else
      log_info "$cmd is ready"
    fi
  done
  
  if [[ "$success" != true ]]; then
    log_error "Some dependencies could not be installed"
    return 1
  fi
  
  return 0
}

install_gcloud() {
  local os_type=$(get_os_type)
  
  case "$os_type" in
    macos)
      brew update && brew install --cask google-cloud-sdk
      ;;
    windows)
      winget install -e --id Google.CloudSDK
      log_warning "Restart your terminal and rerun this script"
      exit 0
      ;;
    linux)
      echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
      curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
      sudo apt-get update && sudo apt-get install google-cloud-sdk -y
      ;;
  esac
  
  # Verify installation
  if ! command -v gcloud &> /dev/null; then
    log_error "Google Cloud SDK installation failed"
    log_warning "Please install manually: https://cloud.google.com/sdk/docs/install"
    return 1
  fi
  
  return 0
}

install_gh() {
  local os_type=$(get_os_type)
  
  case "$os_type" in
    macos)
      brew update && brew install gh
      ;;
    windows)
      winget install -e --id GitHub.cli
      log_warning "Restart your terminal and rerun this script"
      exit 0
      ;;
    linux)
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      sudo apt update && sudo apt install gh -y
      ;;
  esac
  
  return 0
}

install_yq() {
  local os_type=$(get_os_type)
  
  case "$os_type" in
    macos)
      brew update && brew install yq
      ;;
    linux)
      sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
      sudo chmod a+x /usr/local/bin/yq
      ;;
    windows)
      log_warning "Manual yq install needed!\nDownload from: https://github.com/mikefarah/yq\nAdd it to your PATH!"
      return 1
      ;;
  esac
  
  return 0
}

install_jq() {
  local os_type=$(get_os_type)
  
  case "$os_type" in
    macos)
      brew update && brew install jq
      ;;
    linux)
      sudo apt-get update && sudo apt-get install -y jq
      ;;
    windows)
      log_warning "Manual jq install needed!\nDownload from: https://stedolan.github.io/jq/\nAdd it to your PATH!"
      return 1
      ;;
  esac
  
  return 0
}

###################### GITHUB INTEGRATION #####################################

check_github_auth() {
  log_step "Checking GitHub authentication"
  
  if ! gh auth status &>/dev/null; then
    log_warning "Not authenticated with GitHub"
    gh auth login || return 1
  fi
  
  # Get GitHub token
  if [ -z "$GITHUB_TOKEN" ]; then
    export GITHUB_TOKEN=$(gh auth token)
    if [ -z "$GITHUB_TOKEN" ]; then
      log_warning "Could not get GitHub token"
      return 1
    fi
  fi
  
  log_info "GitHub authentication verified"
  git config --global --add safe.directory /repo
  # Get user's repositories
  select_user_repository
  
  return 0
}

create_github_environment() {
  local env_name=$1
  local repo_name=$(gh repo view --json nameWithOwner -q .nameWithOwner)
  
  log_info "Checking if environment '$env_name' exists in repository..."
  
  # Check if environment already exists
  if gh api repos/${repo_name}/environments | grep -q "\"name\":\"$env_name\""; then
    log_info "Environment '$env_name' already exists. Skipping creation."
    return 0
  fi
  
  log_info "Creating GitHub environment: $env_name"
  
  # Create the environment using GitHub API
  if gh api -X PUT repos/${repo_name}/environments/$env_name; then
    log_info "Successfully created GitHub environment: $env_name"
    
    # Configure environment protection rules based on environment type
    case "$env_name" in
      prod)
        # Try to set up protection rules for production environment
        gh api -X PUT repos/${repo_name}/environments/$env_name \
          -f deployment_branch_policy[protected_branches]=true \
          -f deployment_branch_policy[custom_branch_policies]=false \
          && log_info "Set up protection rules for production environment"
        ;;
      staging)
        # Set up basic protection for staging
        gh api -X PUT repos/${repo_name}/environments/$env_name \
          -f deployment_branch_policy[protected_branches]=false \
          -f deployment_branch_policy[custom_branch_policies]=true \
          -f deployment_branch_policy.custom_branch_policies[0].name='main' \
          -f deployment_branch_policy.custom_branch_policies[1].name='staging-*' \
          && log_info "Set up protection rules for staging environment"
        ;;
      dev)
        # Minimal protection for dev environment
        log_info "No special protection rules set for dev environment"
        ;;
    esac
    
    return 0
  else
    log_error "Failed to create GitHub environment: $env_name"
    return 1
  fi
}

select_user_repository() {
  log_step "Selecting your GitHub repository"
  
  # Get repository from git config
  USER_REPO_URL=$(git config --get remote.origin.url)
  USER_REPO_PATH=$(gh repo view --json nameWithOwner -q ".nameWithOwner")
  
  if [ -z "$USER_REPO_URL" ] || [ -z "$USER_REPO_PATH" ]; then
    log_warning "Not in a git repository. Please create or clone a repository first."
    return 1
  fi

  # Log the current repo
  log_info "Current repo url:  $USER_REPO_URL"
  log_info "Current repo name: $USER_REPO_PATH"
  
  # Get short name for GCP project naming
  REPO_NAME=$(echo "$USER_REPO_PATH" | cut -d'/' -f2)
  log_debug "Repository short name: $REPO_NAME"
  
  return 0
}

get_github_variable() {
  local var_name="$1"
  local env_name="$2"  # Optional environment parameter
  
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  [ -z "$GITHUB_TOKEN" ] && export GITHUB_TOKEN=$(gh auth token)
  [ -z "$GITHUB_TOKEN" ] && { log_error "No GitHub token available"; return 1; }
  
  local env_flag=""
  if [ -n "$env_name" ]; then
    env_flag="--env $env_name"
  fi
  
  value=$(GH_TOKEN="$GITHUB_TOKEN" gh variable get "$var_name" -R "$USER_REPO_PATH" $env_flag 2>/dev/null)
  echo "$value"
  return 0
}

set_github_variable() {
  local var_name="$1"
  local var_value="$2"
  local env_name="$3"  # Optional environment parameter
  
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  [ -z "$GITHUB_TOKEN" ] && export GITHUB_TOKEN=$(gh auth token)
  [ -z "$GITHUB_TOKEN" ] && { log_error "No GitHub token available"; return 1; }
  
  local env_flag=""
  local scope_log="repository"
  
  # If an environment was specified, use the --env flag
  if [ -n "$env_name" ]; then
    env_flag="--env $env_name"
    scope_log="environment $env_name"
  fi
  
  log_info "Setting variable $var_name in $scope_log"
  
  if GH_TOKEN="$GITHUB_TOKEN" gh variable set "$var_name" -R "$USER_REPO_PATH" $env_flag -b"$var_value"; then
    log_info "Successfully set variable: $var_name in $scope_log"
    return 0
  else
    log_error "Failed to set variable: $var_name in $scope_log"
    return 1
  fi
}

set_github_secret() {
  local name="$1"
  local value="$2"
  local env_name="$3"  # Optional environment parameter
  
  [ -z "$value" ] && { log_debug "Skipping empty $name - nothing to set"; return 0; }
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  [ -z "$GITHUB_TOKEN" ] && export GITHUB_TOKEN=$(gh auth token)
  [ -z "$GITHUB_TOKEN" ] && { log_error "No GitHub token available"; return 1; }
  
  local env_flag=""
  local scope_log="repository"
  
  # If an environment was specified, use the --env flag
  if [ -n "$env_name" ]; then
    env_flag="--env $env_name"
    scope_log="environment $env_name"
  fi
  
  if ! GH_TOKEN="$GITHUB_TOKEN" gh secret set "$name" -b"$value" -R "$USER_REPO_PATH" $env_flag 2>/dev/null; then
    log_error "Failed to set secret $name in $scope_log"
    return 1
  fi
  
  log_debug "Set GitHub secret: $name in $scope_log"
  return 0
}

check_github_variable() {
  local var_name="$1"
  local env_name="$2"  # Optional environment parameter
  
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  [ -z "$GITHUB_TOKEN" ] && export GITHUB_TOKEN=$(gh auth token)
  [ -z "$GITHUB_TOKEN" ] && { log_error "No GitHub token available"; return 1; }
  
  local env_flag=""
  local scope_log="repository"
  
  # If an environment was specified, use the --env flag
  if [ -n "$env_name" ]; then
    env_flag="--env $env_name"
    scope_log="environment $env_name"
  fi
  
  log_debug "Checking if variable $var_name exists in $scope_log"
  
  if output=$(GH_TOKEN="$GITHUB_TOKEN" gh variable list -R "$USER_REPO_PATH" $env_flag 2>&1); then
    if echo "$output" | grep -q "^$var_name[[:space:]]"; then
      log_debug "Variable $var_name exists in $scope_log"
      return 0
    else
      log_debug "Variable $var_name does not exist in $scope_log"
      return 1
    fi
  else
    log_error "Failed to check variable: $var_name in $scope_log"
    return 1
  fi
}

setup_github_actions_token() {
  log_step "Setting up GitHub tokens for environment: $ENVIRONMENT"
  
  # Check GitHub token
  [ -z "$GITHUB_TOKEN" ] && export GITHUB_TOKEN=$(gh auth token)
  [ -z "$GITHUB_TOKEN" ] && { log_error "No GitHub token available"; return 1; }
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  
  # First, set the token at repository level (global)
  log_info "Setting up repository-level token..."
  if ! GH_TOKEN="$GITHUB_TOKEN" gh secret list -R "$USER_REPO_PATH" 2>/dev/null | grep -q "GHACTIONS_TOKEN"; then
    log_info "Creating repository-level GHACTIONS_TOKEN..."
    if ! GH_TOKEN="$GITHUB_TOKEN" gh secret set GHACTIONS_TOKEN -b"$GITHUB_TOKEN" -R "$USER_REPO_PATH"; then
      log_error "Failed to set repository-level GHACTIONS_TOKEN"
      return 1
    fi
    log_info "Repository-level GHACTIONS_TOKEN set successfully"
  else
    log_info "Repository-level GHACTIONS_TOKEN already exists"
  fi
  
  # Now set environment-specific secrets
  log_info "Setting up environment-specific secrets for: $ENVIRONMENT"
  
  # Define environment-specific variables based on the environment
  declare -A env_secrets
  
  # Common secrets for all environments
  env_secrets["GHACTIONS_TOKEN"]="$GITHUB_TOKEN"
  
  # Environment-specific secrets
  case "$ENVIRONMENT" in
    prod)
      env_secrets["SENSITIVE_VALUE"]="DATA_PROD"     
      ;;
    staging)
      env_secrets["SENSITIVE_VALUE"]="DATA_PROD"
      ;;
    dev)
      env_secrets["SENSITIVE_VALUE"]="DATA_PROD"
      ;;
  esac
  
  # Set each secret for the specific environment
  for secret_name in "${!env_secrets[@]}"; do
    secret_value="${env_secrets[$secret_name]}"
    
    log_info "Setting $secret_name for environment $ENVIRONMENT..."
    if ! GH_TOKEN="$GITHUB_TOKEN" gh secret set "$secret_name" -b"$secret_value" -R "$USER_REPO_PATH" --env "$ENVIRONMENT"; then
      log_error "Failed to set $secret_name for environment $ENVIRONMENT"
      return 1
    fi
    log_info "Set $secret_name for environment $ENVIRONMENT"
  done
  
  log_info "All secrets configured successfully for environment: $ENVIRONMENT"
  return 0
}

###################### AUTHENTICATION MANAGEMENT ##############################

check_gcp_auth() {
  log_step "Checking GCP authentication"
  
  # Check if already authenticated
  if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
    local current_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
    log_info "Authenticated as $current_account"
    
    # Check if active project is set
    local current_project=$(gcloud config get-value project 2>/dev/null)
    if [[ -n "$current_project" ]]; then
      log_info "Current project: $current_project"
      
      # Check if a project is already defined in GitHub environment
      local env_project=$(get_github_variable "GCP_PROJECT_ID" "$ENVIRONMENT")
      
      if [[ -n "$env_project" ]]; then
        log_info "Found project ID in GitHub environment: $env_project"
        
        # Ask about changing projects if they differ
        if [[ "$current_project" != "$env_project" ]]; then
          log_warning "Current GCP project differs from GitHub environment variable"
          read -e -p "Use GitHub environment project ($env_project)? (Y/n): " use_env_project
          if [[ ! "$use_env_project" =~ ^[Nn]$ ]]; then
            gcloud config set project "$env_project"
            export GCP_PROJECT=$env_project
            log_info "Set active project to GitHub environment project: $env_project"
          else
            read -e -p "Use current GCP project ($current_project)? (Y/n): " use_current_project
            if [[ ! "$use_current_project" =~ ^[Nn]$ ]]; then
              export GCP_PROJECT=$current_project
              set_github_variable "GCP_PROJECT_ID" "$current_project" "$ENVIRONMENT"
              log_info "Updated GitHub environment variable with current project: $current_project"
            else
              select_gcp_project || return 1
            fi
          fi
        else
          export GCP_PROJECT=$current_project
          log_info "Using project: $current_project (matches GitHub environment)"
        fi
      else
        # No project in GitHub environment, ask about current project
        read -e -p "Use current project ($current_project)? (Y/n): " use_current
        if [[ ! "$use_current" =~ ^[Nn]$ ]]; then
          export GCP_PROJECT=$current_project
          set_github_variable "GCP_PROJECT_ID" "$current_project" "$ENVIRONMENT"
          log_info "Set GitHub environment variable GCP_PROJECT_ID to: $current_project"
        else
          select_gcp_project || return 1
        fi
      fi
    else
      log_warning "No active project set"
      select_gcp_project || return 1
    fi
  else
    log_warning "Not logged in to Google Cloud"
    gcloud auth login || return 1
    log_info "Authentication successful"
    select_gcp_project || return 1
  fi
  
  # Check application default credentials
  if [ ! -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
    log_warning "Setting up Application Default Credentials"
    gcloud auth application-default login || return 1
  else
    log_debug "Application Default Credentials configured"
  fi
  
  return 0
}

select_gcp_project() {
  log_step "Selecting GCP project"
  
  # Check if project already defined in GitHub environment
  local env_project=$(get_github_variable "GCP_PROJECT_ID" "$ENVIRONMENT")
  if [[ -n "$env_project" ]]; then
    log_info "Found project ID in GitHub environment: $env_project"
    read -e -p "Use this project? (Y/n): " use_env_project
    if [[ ! "$use_env_project" =~ ^[Nn]$ ]]; then
      gcloud config set project "$env_project"
      export GCP_PROJECT=$env_project
      log_info "Set active project to: $env_project"
      return 0
    fi
  fi
  
  # Check if repo name should be used for project
  local repo_short_name=""
  if [ -n "$USER_REPO_PATH" ]; then
    repo_short_name=$(echo "$USER_REPO_PATH" | cut -d'/' -f2)
    
    if gcloud projects describe "$repo_short_name" &>/dev/null; then
      log_info "Found matching project: $repo_short_name"
      read -e -p "Use this project? (Y/n): " use_repo_project
      if [[ ! "$use_repo_project" =~ ^[Nn]$ ]]; then
        gcloud config set project "$repo_short_name"
        export GCP_PROJECT=$repo_short_name
        set_github_variable "GCP_PROJECT_ID" "$repo_short_name" "$ENVIRONMENT"
        log_info "Set active project to: $repo_short_name"
        return 0
      fi
    fi
  fi
  
  # Get list of projects
  log_info "Fetching GCP projects..."
  local projects=$(gcloud projects list --format="value(projectId)")
  
  if [ -z "$projects" ]; then
    log_warning "No projects found"
    read -e -p "Create a new project? (Y/n): " create_new
    if [[ ! "$create_new" =~ ^[Nn]$ ]]; then
      create_gcp_project || return 1
    else
      log_error "No projects available"
      return 1
    fi
    return 0
  fi
  
  # Display projects for selection
  echo -e "\nAvailable projects:"
  local i=1
  local project_array=()
  
  while read -r project; do
    echo "  $i) $project"
    project_array+=("$project")
    ((i++))
  done <<< "$projects"
  
  echo "  $i) Create a new project"
  
  # Select project
  read -e -p "Select a project (1-$i): " project_choice
  
  if [ "$project_choice" -eq "$i" ]; then
    create_gcp_project || return 1
  elif [ "$project_choice" -ge 1 ] && [ "$project_choice" -lt "$i" ]; then
    local selected=${project_array[$((project_choice-1))]}
    gcloud config set project "$selected"
    export GCP_PROJECT=$selected
    set_github_variable "GCP_PROJECT_ID" "$selected" "$ENVIRONMENT"
    log_info "Set active project to: $selected"
    log_info "Set GCP_PROJECT_ID variable in GitHub for environment: $ENVIRONMENT"
    
    return 0
  else
    log_error "Invalid selection"
    return 1
  fi
}

create_gcp_project() {
  log_step "Creating new GCP project"
  
  # Default to repo name or prompt
  local default_name=""
  if [ -n "$USER_REPO_PATH" ]; then
    default_name="${ENVIRONMENT}-$(echo "$USER_REPO_PATH" | cut -d'/' -f2)"
  else
    default_name="${ENVIRONMENT}-my-gcp-project-$(date +%m%d)"
  fi
  
  read -e -p "Enter new project ID (default: $default_name): " project_id
  project_id=${project_id:-$default_name}
  
  # Convert to lowercase and ensure valid format
  project_id=$(echo "$project_id" | tr '[:upper:]' '[:lower:]')
  
  # Validate project ID
  if ! [[ $project_id =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
    log_error "Invalid project ID format"
    log_warning "Project ID must start with a letter, contain only lowercase letters, numbers, or hyphens, and be 6-30 characters"
    return 1
  fi
  
  # Project display name
  read -e -p "Enter project name [default: $project_id]: " project_name
  project_name=${project_name:-$project_id}
  
  # Create project
  log_info "Creating project: $project_name ($project_id)"
  if ! gcloud projects create "$project_id" --name="$project_name"; then
    log_error "Failed to create project"
    return 1
  fi
  
  log_info "Project created successfully"
  gcloud config set project "$project_id"
  export GCP_PROJECT=$project_id
  
  # Update GitHub environment variable
  set_github_variable "GCP_PROJECT_ID" "$project_id" "$ENVIRONMENT"
  
  # Enable required APIs
  log_info "Enabling required APIs..."
  gcloud services enable cloudbuild.googleapis.com \
                       cloudresourcemanager.googleapis.com \
                       iam.googleapis.com \
                       compute.googleapis.com \
                       storage.googleapis.com
  
  log_info "Project setup complete: $project_id"
  return 0
}

###################### RESOURCE MANAGEMENT ###################################

set_gcp_region() {
  log_step "Configuring GCP Region"
  
  # Check if region already defined in GitHub environment
  local env_region=$(get_github_variable "GCP_REGION" "$ENVIRONMENT")
  if [[ -n "$env_region" ]]; then
    log_info "Found region in GitHub environment: $env_region"
    read -e -p "Use this region? (Y/n): " use_env_region
    if [[ ! "$use_env_region" =~ ^[Nn]$ ]]; then
      export GCP_REGION=$env_region
      log_info "Using region from GitHub environment: $env_region"
      return 0
    fi
  fi
  
  # Get available regions
  log_info "Fetching GCP regions..."
  local regions=$(gcloud compute regions list --format="value(name)")
  
  # Display regions for selection
  echo -e "\nAvailable regions:"
  local i=1
  local region_array=()
  
  while read -r region; do
    echo "  $i) $region"
    region_array+=("$region")
    ((i++))
  done <<< "$regions"
  
  # Select region
  local default_region_num=1  # us-central1 is usually first
  read -e -p "Select a region (1-$((i-1)), default: $default_region_num for ${region_array[$((default_region_num-1))]}): " region_choice
  region_choice=${region_choice:-$default_region_num}
  
  if [ "$region_choice" -ge 1 ] && [ "$region_choice" -lt "$i" ]; then
    local selected=${region_array[$((region_choice-1))]}
    export GCP_REGION=$selected
    set_github_variable "GCP_REGION" "$selected" "$ENVIRONMENT"
    log_info "Set region to: $selected"
    log_info "Set GCP_REGION variable in GitHub for environment: $ENVIRONMENT"
    
    # Now get a zone in this region
    set_gcp_zone "$selected"
    
    return 0
  else
    log_error "Invalid selection"
    return 1
  fi
}

set_gcp_zone() {
  local region="$1"
  log_step "Configuring GCP Zone"
  
  # Check if zone already defined in GitHub environment
  local env_zone=$(get_github_variable "GCP_ZONE" "$ENVIRONMENT")
  if [[ -n "$env_zone" ]]; then
    log_info "Found zone in GitHub environment: $env_zone"
    read -e -p "Use this zone? (Y/n): " use_env_zone
    if [[ ! "$use_env_zone" =~ ^[Nn]$ ]]; then
      export GCP_ZONE=$env_zone
      log_info "Using zone from GitHub environment: $env_zone"
      return 0
    fi
  fi
  
  # Get available zones in the selected region
  log_info "Fetching zones in region $region..."
  local zones=$(gcloud compute zones list --filter="region:( $region )" --format="value(name)")
  
  # Display zones for selection
  echo -e "\nAvailable zones in $region:"
  local i=1
  local zone_array=()
  
  while read -r zone; do
    echo "  $i) $zone"
    zone_array+=("$zone")
    ((i++))
  done <<< "$zones"
  
  # Select zone
  local default_zone_num=1  # First zone in region
  read -e -p "Select a zone (1-$((i-1)), default: $default_zone_num for ${zone_array[$((default_zone_num-1))]}): " zone_choice
  zone_choice=${zone_choice:-$default_zone_num}
  
  if [ "$zone_choice" -ge 1 ] && [ "$zone_choice" -lt "$i" ]; then
    local selected=${zone_array[$((zone_choice-1))]}
    export GCP_ZONE=$selected
    set_github_variable "GCP_ZONE" "$selected" "$ENVIRONMENT"
    log_info "Set zone to: $selected"
    log_info "Set GCP_ZONE variable in GitHub for environment: $ENVIRONMENT"
    
    return 0
  else
    log_error "Invalid selection"
    return 1
  fi
}

scan_and_select_vpc() {
  log_step "Scanning and selecting VPC"
  
  # Ensure we have a project
  [ -z "$GCP_PROJECT" ] && { log_error "No GCP project set"; return 1; }
  
  # Check if networking option is already defined in GitHub environment
  local env_networking=$(get_github_variable "NETWORKING_OPTION" "$ENVIRONMENT")
  local env_vpc=$(get_github_variable "VPC_NAME" "$ENVIRONMENT")
  
  if [[ -n "$env_networking" && -n "$env_vpc" ]]; then
    log_info "Found networking configuration in GitHub environment:"
    log_info "Networking option: $env_networking"
    log_info "VPC name: $env_vpc"
    
    read -e -p "Use this networking configuration? (Y/n): " use_env_networking
    if [[ ! "$use_env_networking" =~ ^[Nn]$ ]]; then
      export NETWORKING_OPTION=$env_networking
      export VPC_NAME=$env_vpc
      log_info "Using networking configuration from GitHub environment"
      return 0
    fi
  fi
  
  # Check if Compute Engine API is enabled
  if ! gcloud services list --enabled --filter="name:compute.googleapis.com" | grep -q "compute.googleapis.com"; then
    log_info "Enabling Compute Engine API..."
    gcloud services enable compute.googleapis.com || {
      log_error "Failed to enable Compute Engine API"
      return 1
    }
  fi
  
  # Scan for existing VPCs
  log_info "Scanning for existing VPCs in project $GCP_PROJECT..."
  local vpc_list=$(gcloud compute networks list --project="$GCP_PROJECT" --format="value(name)")
  
  # Check if any VPCs exist
  if [ -z "$vpc_list" ]; then
    log_info "No existing VPCs found in project $GCP_PROJECT"
    read -e -p "Let Terraform create a new VPC? (Y/n): " create_vpc
    if [[ ! "$create_vpc" =~ ^[Nn]$ ]]; then
      export NETWORKING_OPTION="create_new"
      export VPC_NAME="tf-${ENVIRONMENT}-vpc"
      log_info "Set networking option to: create_new"
      set_github_variable "NETWORKING_OPTION" "create_new" "$ENVIRONMENT"
      set_github_variable "VPC_NAME" "$VPC_NAME" "$ENVIRONMENT"
    else
      log_error "No VPC available for use"
      return 1
    fi
  else
    # Display VPCs for selection
    echo -e "\nExisting VPCs in project $GCP_PROJECT:"
    local i=1
    local vpc_array=()
    
    while read -r vpc; do
      echo "  $i) $vpc"
      vpc_array+=("$vpc")
      ((i++))
    done <<< "$vpc_list"
    
    echo "  $i) Let Terraform Create a new VPC"
    
    # Select VPC
    read -e -p "Select a VPC (1-$i): " vpc_choice
    
    if [ "$vpc_choice" -eq "$i" ]; then
      export NETWORKING_OPTION="create_new"
      export VPC_NAME="tf-${ENVIRONMENT}-vpc"
      log_info "Set networking option to: create_new"
      set_github_variable "NETWORKING_OPTION" "create_new" "$ENVIRONMENT"
      set_github_variable "VPC_NAME" "$VPC_NAME" "$ENVIRONMENT"
    elif [ "$vpc_choice" -ge 1 ] && [ "$vpc_choice" -lt "$i" ]; then
      local selected=${vpc_array[$((vpc_choice-1))]}
      export NETWORKING_OPTION="use_existing"
      export VPC_NAME="$selected"
      log_info "Selected VPC: $selected"
      log_info "Set networking option to: use_existing"
      set_github_variable "NETWORKING_OPTION" "use_existing" "$ENVIRONMENT"
      set_github_variable "VPC_NAME" "$selected" "$ENVIRONMENT"
    else
      log_error "Invalid selection"
      return 1
    fi
  fi
  
  log_info "VPC selection complete"
  return 0
}

scan_and_select_subnet() {
  log_step "Scanning and selecting Subnet"
  
  # Only run if we're using an existing VPC
  if [ "$NETWORKING_OPTION" != "use_existing" ] || [ -z "$VPC_NAME" ]; then
    log_debug "Skipping subnet selection - not using existing VPC"
    return 0
  fi
  
  # Ensure we have a project
  [ -z "$GCP_PROJECT" ] && { log_error "No GCP project set"; return 1; }
  
  # Check if subnet is already defined in GitHub environment
  local env_subnet=$(get_github_variable "SUBNET_NAME" "$ENVIRONMENT")
  
  if [[ -n "$env_subnet" ]]; then
    log_info "Found subnet in GitHub environment: $env_subnet"
    
    read -e -p "Use this subnet? (Y/n): " use_env_subnet
    if [[ ! "$use_env_subnet" =~ ^[Nn]$ ]]; then
      export SUBNET_NAME=$env_subnet
      log_info "Using subnet from GitHub environment: $env_subnet"
      return 0
    fi
  fi
  
  # Get region from GitHub environment or use default
  local region=$(get_github_variable "GCP_REGION" "$ENVIRONMENT")
  [ -z "$region" ] && region="$GCP_REGION"
  [ -z "$region" ] && region="$DEFAULT_GCP_REGION"
  
  # Scan for existing subnets in the selected VPC and region
  log_info "Scanning for existing subnets in VPC '$VPC_NAME' and region '$region'..."
  local subnet_list=$(gcloud compute networks subnets list \
    --project="$GCP_PROJECT" \
    --network="$VPC_NAME" \
    --regions="$region" \
    --format="value(name)")
  
  # Check if any subnets exist
  if [ -z "$subnet_list" ]; then
    log_info "No existing subnets found in VPC '$VPC_NAME' in region '$region'"
    log_warning "No subnet available for use in the selected region"
    # Ask if they want to try another region
    read -e -p "Try another region? (Y/n): " try_other
    if [[ ! "$try_other" =~ ^[Nn]$ ]]; then
      # Get available regions with subnets in this VPC
      local regions=$(gcloud compute networks subnets list \
        --project="$GCP_PROJECT" \
        --network="$VPC_NAME" \
        --format="value(region)" | sort | uniq)
      
      if [ -z "$regions" ]; then
        log_error "No subnets found in any region for VPC '$VPC_NAME'"
        return 1
      fi
      
      # Display regions for selection
      echo -e "\nRegions with subnets in VPC '$VPC_NAME':"
      local i=1
      local region_array=()
      
      while read -r reg; do
        echo "  $i) $reg"
        region_array+=("$reg")
        ((i++))
      done <<< "$regions"
      
      # Select region
      read -e -p "Select a region (1-$((i-1))): " region_choice
      
      if [ "$region_choice" -ge 1 ] && [ "$region_choice" -lt "$i" ]; then
        region=${region_array[$((region_choice-1))]}
        set_github_variable "GCP_REGION" "$region" "$ENVIRONMENT"
        export GCP_REGION=$region
        log_info "Selected region: $region"
        log_info "Updated GCP_REGION in GitHub environment: $ENVIRONMENT"
        # Recursive call with new region
        scan_and_select_subnet
        return $?
      else
        log_error "Invalid selection"
        return 1
      fi
    else
      # Let Terraform create a subnet in the current region
      export SUBNET_NAME="tf-${ENVIRONMENT}-subnet"
      set_github_variable "SUBNET_NAME" "$SUBNET_NAME" "$ENVIRONMENT"
      log_info "Terraform will create a new subnet"
      return 0
    fi
  fi
  
  # Display subnets for selection
  echo -e "\nExisting subnets in VPC '$VPC_NAME' (region '$region'):"
  local i=1
  local subnet_array=()
  
  while read -r subnet; do
    # Get subnet details
    local cidr=$(gcloud compute networks subnets describe "$subnet" \
      --project="$GCP_PROJECT" \
      --region="$region" \
      --format="value(ipCidrRange)")
    
    echo "  $i) $subnet ($cidr)"
    subnet_array+=("$subnet")
    ((i++))
  done <<< "$subnet_list"
  
  echo "  $i) Let Terraform create a new subnet"
  
  # Select subnet
  read -e -p "Select a subnet (1-$i): " subnet_choice
  
  if [ "$subnet_choice" -eq "$i" ]; then
    # User wants to create a new subnet
    export SUBNET_NAME="tf-${ENVIRONMENT}-subnet"
    set_github_variable "SUBNET_NAME" "$SUBNET_NAME" "$ENVIRONMENT"
    log_info "Terraform will create a new subnet: $SUBNET_NAME"
  elif [ "$subnet_choice" -ge 1 ] && [ "$subnet_choice" -lt "$i" ]; then
    local selected=${subnet_array[$((subnet_choice-1))]}
    export SUBNET_NAME="$selected"
    set_github_variable "SUBNET_NAME" "$selected" "$ENVIRONMENT"
    log_info "Selected subnet: $selected"
    log_info "Updated SUBNET_NAME in GitHub environment: $ENVIRONMENT"
  else
    log_error "Invalid selection"
    return 1
  fi
  
  log_info "Subnet selection complete"
  return 0
}

setup_terraform_storage() {
  log_step "Setting up Terraform storage"
  
  # Ensure we have a project
  [ -z "$GCP_PROJECT" ] && { log_error "No GCP project set"; return 1; }
  
  # Check if bucket already defined in GitHub environment
  local env_bucket=$(get_github_variable "BACKEND_STORAGE_ACCOUNT" "$ENVIRONMENT")
  
  if [[ -n "$env_bucket" ]]; then
    log_info "Found storage bucket in GitHub environment: $env_bucket"
    
    if gsutil ls -p "$GCP_PROJECT" "gs://$env_bucket" &>/dev/null; then
      log_info "Bucket gs://$env_bucket exists"
      read -e -p "Use this bucket? (Y/n): " use_env_bucket
      if [[ ! "$use_env_bucket" =~ ^[Nn]$ ]]; then
        export BUCKET_NAME=$env_bucket
        log_info "Using bucket from GitHub environment: $env_bucket"
        return 0
      fi
    else
      log_warning "Bucket gs://$env_bucket does not exist in project $GCP_PROJECT"
    fi
  fi
  
  # Get region from GitHub environment
  local region=$(get_github_variable "GCP_REGION" "$ENVIRONMENT")
  [ -z "$region" ] && region="$GCP_REGION"
  [ -z "$region" ] && region="$DEFAULT_GCP_REGION"
  
  # Create new bucket name
  if [ -n "$USER_REPO_PATH" ]; then
    local repo_short_name=$(echo "$USER_REPO_PATH" | cut -d'/' -f2 | tr '[:upper:]' '[:lower:]')
    BUCKET_NAME="${ENVIRONMENT}-${repo_short_name}-tfstate-$GCP_PROJECT"
  else
    BUCKET_NAME="${ENVIRONMENT}-${GCP_PROJECT}-tfstate"
  fi
  
  # Ensure bucket name is lowercase and valid
  BUCKET_NAME=$(echo "$BUCKET_NAME" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
  BUCKET_NAME=$(echo "$BUCKET_NAME" | cut -c 1-60)  # Limit length
  
  log_info "Using bucket name: $BUCKET_NAME"
  
  if gsutil ls -p "$GCP_PROJECT" "gs://$BUCKET_NAME" &>/dev/null; then
    log_info "Bucket gs://$BUCKET_NAME already exists"
  else
    # Create the bucket
    log_info "Creating bucket gs://$BUCKET_NAME in $region"
    if ! gsutil mb -p "$GCP_PROJECT" -l "$region" "gs://$BUCKET_NAME"; then
      log_error "Failed to create bucket"
      return 1
    fi
    
    # Enable versioning
    log_info "Enabling versioning"
    gsutil versioning set on "gs://$BUCKET_NAME"
    
    # Set lifecycle policy
    log_info "Setting lifecycle management"
    cat > "/tmp/lifecycle.json" << EOL
{
  "rule": [
    {
      "action": {
        "type": "Delete"
      },
      "condition": {
        "numNewerVersions": 10,
        "isLive": false
      }
    }
  ]
}
EOL
    gsutil lifecycle set "/tmp/lifecycle.json" "gs://$BUCKET_NAME"
  fi
  
  # Set GitHub variable
  set_github_variable "BACKEND_STORAGE_ACCOUNT" "$BUCKET_NAME" "$ENVIRONMENT"
  log_info "Set BACKEND_STORAGE_ACCOUNT variable in GitHub for environment: $ENVIRONMENT"
  
  log_info "Terraform storage setup complete"
  return 0
}

create_service_account() {
  log_step "Creating Service Account for GitHub Actions"
  
  # Ensure we have a project
  [ -z "$GCP_PROJECT" ] && { log_error "No GCP project set"; return 1; }
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  
  # Check if service account already defined in GitHub environment
  local env_sa=$(get_github_variable "SERVICE_ACCOUNT" "$ENVIRONMENT")
  
  if [[ -n "$env_sa" ]]; then
    log_info "Found service account in GitHub environment: $env_sa"
    
    # Check if service account exists in GCP
    if gcloud iam service-accounts describe "$env_sa" &>/dev/null; then
      log_info "Service account exists in GCP: $env_sa"
      read -e -p "Use this service account? (Y/n): " use_env_sa
      if [[ ! "$use_env_sa" =~ ^[Nn]$ ]]; then
        export SERVICE_ACCOUNT=$env_sa
        log_info "Using service account from GitHub environment: $env_sa"
        return 0
      fi
    else
      log_warning "Service account does not exist in GCP: $env_sa"
    fi
  fi
  
  # Create service account name
  local repo_short_name=$(echo "$USER_REPO_PATH" | cut -d'/' -f2 | tr '[:upper:]' '[:lower:]')
  local sa_name="${repo_short_name}-gha"
  local sa_display_name="GitHub Actions for ${repo_short_name} (${ENVIRONMENT})"
  local sa_email="${sa_name}@${GCP_PROJECT}.iam.gserviceaccount.com"
  
  # Check if service account exists
  if gcloud iam service-accounts list --filter="email:$sa_email" | grep -q "$sa_email"; then
    log_info "Service account $sa_email already exists"
  else
    # Create service account
    log_info "Creating service account $sa_name"
    if ! gcloud iam service-accounts create "$sa_name" \
         --display-name="$sa_display_name" \
         --description="Service account for GitHub Actions integration with environment: $ENVIRONMENT"; then
      log_error "Failed to create service account"
      return 1
    fi
  fi
  
  sleep 5  # Allow time for service account creation to propagate
  
  # Grant permissions
  log_info "Granting permissions to service account"
  
  readonly ROLES=(
    # General CRUD on resources you manage
    roles/compute.admin            # VMs, disks, addresses, forwarding rules
    roles/container.admin          # GKE clusters (Autopilot & Standard)
    roles/storage.admin            # GCS buckets & objects
    roles/cloudsql.admin           # Cloud SQL instances & users
    roles/secretmanager.admin
    roles/servicenetworking.networksAdmin
    roles/artifactregistry.admin
    roles/documentai.admin
    roles/datastore.owner
    roles/aiplatform.admin
    roles/servicemanagement.admin # Service managment admin
    roles/serviceusage.apiKeysAdmin
    roles/dns.admin


    # IAM administration needed by the pipeline
    roles/iam.serviceAccountAdmin  # create/update SAs, grant them roles
    roles/iam.securityAdmin        # set IAM policies at project/resource level
    roles/iam.serviceAccountKeyAdmin   # (optional) manage SA keys, if you ever need them
    roles/iam.workloadIdentityPoolAdmin # create/update WIF pools/providers
    roles/iam.serviceAccountUser

    # Enable / disable Google APIs on-the-fly
    roles/serviceusage.serviceUsageAdmin
  )

  for role in "${ROLES[@]}"; do
    log_debug "Granting role $role to $sa_email"
    gcloud projects add-iam-policy-binding "$GCP_PROJECT" \
      --member="serviceAccount:${sa_email}" \
      --role="$role" \
      --quiet
  done
    
  # Ask user if they want to use Workload Identity Federation (recommended) 
  log_warning "GitHub Actions can authenticate with GCP using Workload Identity Federation"
  read -e -p "Use Workload Identity Federation? (Y/n): " use_wif
  
  if [[ ! "$use_wif" =~ ^[Nn]$ ]]; then
    # Set up Workload Identity Federation
    setup_workload_identity_federation "$sa_email" || return 1
  else
    return 1
  fi
  
  log_info "Service account setup complete"
  return 0
}

setup_workload_identity_federation() {
  local sa_email="$1"
  local repo_owner=$(echo "$USER_REPO_PATH" | cut -d'/' -f1)
  local repo_name=$(echo "$USER_REPO_PATH" | cut -d'/' -f2)
  
  log_step "Setting up Workload Identity Federation for GitHub Actions"
  
  # Check if provider already defined in GitHub environment
  local env_provider=$(get_github_variable "WORKLOAD_IDENTITY_PROVIDER" "$ENVIRONMENT")
  
  if [[ -n "$env_provider" && -n "$sa_email" ]]; then
    log_info "Found Workload Identity Provider in GitHub environment:"
    log_info "Provider: $env_provider"
    log_info "Service Account: $sa_email"
    
    read -e -p "Use this configuration? (Y/n): " use_env_provider
    if [[ ! "$use_env_provider" =~ ^[Nn]$ ]]; then
      export WORKLOAD_IDENTITY_PROVIDER=$env_provider
      export SERVICE_ACCOUNT=$sa_email
      log_info "Using Workload Identity Federation configuration from GitHub environment"
      return 0
    fi
  fi
  
  # Enable required APIs
  log_info "Enabling IAM Credentials API..."
  gcloud services enable iamcredentials.googleapis.com
  gcloud services enable cloudresourcemanager.googleapis.com
  
  # Create Workload Identity Pool if it doesn't exist
  local pool_id="github-actions-pool"
  local pool_display_name="GitHub Actions Pool"

  if gcloud iam workload-identity-pools list --location="global" | grep -q "$pool_id"; then
    log_info "Workload Identity Pool $pool_id already exists"
  else
    log_info "Creating Workload Identity Pool..."
    if ! gcloud iam workload-identity-pools create "$pool_id" \
         --location="global" \
         --display-name="$pool_display_name" \
         --description="Identity pool for GitHub Actions"; then
      log_error "Failed to create Workload Identity Pool"
      return 1
    fi
  fi
  
  sleep 3  # Allow time for pool creation to propagate
  
  # Get workload identity pools and project number
  local pool_list=$(gcloud iam workload-identity-pools list --location="global" --format="value(name)")
  if [ -z "$pool_list" ]; then
    log_error "No workload identity pools found"
    return 1
  fi

  # Use the specific provider
  local PROJECT_NUMBER=$(gcloud projects describe "$GCP_PROJECT" --format="value(projectNumber)")
  local pool_name="projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$pool_id"
  log_info "Using pool: $pool_name"
  
  # Create Workload Identity Provider for GitHub Actions
  local provider_id="github-provider"
  local provider_display_name="GitHub Provider"
  
  if gcloud iam workload-identity-pools providers list \
       --workload-identity-pool="$pool_id" \
       --location="global" | grep -q "$provider_id"; then
    log_info "Workload Identity Provider $provider_id already exists"
  else
    log_info "Creating Workload Identity Provider..."
    if ! gcloud iam workload-identity-pools providers create-oidc "$provider_id" \
         --workload-identity-pool="$pool_id" \
         --location="global" \
         --display-name="$provider_display_name" \
         --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
         --attribute-condition="attribute.repository=='${repo_owner}/${repo_name}'" \
         --issuer-uri="https://token.actions.githubusercontent.com"; then
      log_error "Failed to create Workload Identity Provider"
      return 1
    fi
  fi
  
  sleep 3  # Allow time for provider creation to propagate
  
  # Allow authentications from the specified repository to impersonate the service account
  log_info "Setting up IAM policy binding..."
  
  if ! gcloud iam service-accounts add-iam-policy-binding "$sa_email" \
       --role="roles/iam.workloadIdentityUser" \
       --member="principalSet://iam.googleapis.com/${pool_name}/attribute.repository/${repo_owner}/${repo_name}"; then
    log_error "Failed to add IAM policy binding"
    return 1
  fi
  
  # Get provider name for GitHub Actions
  local provider_name="projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$pool_id/providers/$provider_id"
  
  # Set GitHub variables for Workload Identity Federation
  set_github_variable "WORKLOAD_IDENTITY_PROVIDER" "$provider_name" "$ENVIRONMENT"
  set_github_variable "SERVICE_ACCOUNT" "$sa_email" "$ENVIRONMENT"
  
  log_info "Workload Identity Federation setup complete"
  log_info "GitHub workflow will use the following configuration:"
  echo -e "Workload Identity Provider: ${CYAN}$provider_name${NC}"
  echo -e "Service Account: ${CYAN}$sa_email${NC}"
  
  return 0
}

###################### WORKFLOW MANAGEMENT ###################################

run_workflow() {
  log_step "Running GitHub workflow"
  
  # Check prerequisites
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  
  # Check if workflow exists
  if ! gh workflow list -R "$USER_REPO_PATH" 2>/dev/null | grep -q "Deploy Google Cloud Infrastructure"; then
    log_warning "Workflow 'Deploy Google Cloud Infrastructure' not found"
    log_info "Please ensure the workflow file has been pushed to the repository"
    return 1
  fi
  
  # Run workflow
  log_info "Starting 'Deploy Google Cloud Infrastructure' workflow..."
  if ! gh workflow run "Deploy Google Cloud Infrastructure" -R "$USER_REPO_PATH"; then
    log_error "Failed to start workflow"
    return 1
  fi
  
  log_info "Workflow started successfully"
  
  # Ask to monitor progress
  read -e -p "Monitor workflow progress? (Y/n): " monitor
  if [[ ! "$monitor" =~ ^[Nn]$ ]]; then
    monitor_workflow "Deploy Google Cloud Infrastructure" || {
      log_warning "Workflow did not complete successfully"
      return 1
    }
  else
    log_info "You can check the workflow status in the GitHub Actions tab"
  fi
  
  return 0
}

run_app_ci_workflow() {
  local workflow_name="Application CI/CD"

  log_step "Running GitHub workflow: $workflow_name"

  # Check prerequisites
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }

  # Check if workflow exists
  if ! gh workflow list -R "$USER_REPO_PATH" \
       | grep -qF "$workflow_name"; then
    log_warning "Workflow '$workflow_name' not found"
    log_info    "Please ensure the workflow file has been pushed to the repository"
    return 1
  fi

  # Run workflow
  log_info "Starting '$workflow_name' workflow..."
  if ! gh workflow run "$workflow_name" -R "$USER_REPO_PATH"; then
    log_error "Failed to start workflow"
    return 1
  fi

  log_info "Workflow started successfully"

  # Ask to monitor progress
  read -e -p "Monitor '$workflow_name' progress? (Y/n): " monitor
  if [[ ! "$monitor" =~ ^[Nn]$ ]]; then
    monitor_workflow "$workflow_name" || {
      log_warning "Workflow did not complete successfully"
      return 1
    }
  else
    log_info "You can check the workflow status in the GitHub Actions tab"
  fi

  return 0
}

monitor_workflow() {
  log_step "Monitoring workflow"
  local workflow_name="$1"
  
  # Check prerequisites
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  [ -z "$GITHUB_TOKEN" ] && export GITHUB_TOKEN=$(gh auth token)
  [ -z "$GITHUB_TOKEN" ] && { log_error "No GitHub token available"; return 1; }
  
  # Get latest run
  log_info "Fetching latest '$workflow_name' run..."
  local run_id=$(GH_TOKEN="$GITHUB_TOKEN" gh run list --workflow="$workflow_name" -R "$USER_REPO_PATH" --limit 1 --json databaseId --jq '.[0].databaseId')
  if [ -z "$run_id" ]; then
    log_error "No runs found for workflow: $workflow_name"
    return 1
  fi
  
  log_info "Run ID: $run_id"
  echo -e "View in browser: ${CYAN}https://github.com/$USER_REPO_PATH/actions/runs/$run_id${NC}"
  
  # Monitor status
  local status="in_progress"
  local previous_status=""
  
  while [ "$status" == "in_progress" ] || [ "$status" == "queued" ] || [ "$status" == "waiting" ]; do
    status=$(GH_TOKEN="$GITHUB_TOKEN" gh run view "$run_id" -R "$USER_REPO_PATH" --json status --jq '.status')
    if [ "$status" != "$previous_status" ]; then
      log_info "Status: $status"
      previous_status="$status"
    fi
    
    # Show job details
    local jobs_json=$(GH_TOKEN="$GITHUB_TOKEN" gh run view "$run_id" -R "$USER_REPO_PATH" --json jobs --jq '.jobs')
    if [ -n "$jobs_json" ]; then
      echo "$jobs_json" | jq -r '.[] | "  Job: \(.name) - Status: \(.status)"' 2>/dev/null || true
    fi
    
    sleep 10
  done
  
  local conclusion=$(GH_TOKEN="$GITHUB_TOKEN" gh run view "$run_id" -R "$USER_REPO_PATH" --json conclusion --jq '.conclusion')
  log_info "Result: $conclusion"
  
  [ "$conclusion" == "success" ] && return 0 || return 1
}

###################### MAIN EXECUTION FLOW ###################################

# Main function to orchestrate execution
main() {
  display_script_overview
  
  log_step "Starting GCP deployment setup"
  
  # Step 1: Check and install dependencies
  install_dependencies || { log_error "Dependency installation failed"; return 1; }
  
  # Step 2: Handle GitHub authentication and repository selection
  check_github_auth || { log_error "GitHub authentication failed"; return 1; }
  
  # Step 3: Select environment
  read -e -p "Enter the environment you want to deploy (dev/staging/prod) [default: dev]: " input_env
  ENVIRONMENT=${input_env:-$DEFAULT_ENV}
  export ENVIRONMENT
  log_info "Environment set to: $ENVIRONMENT"
  
  # Create the GitHub environment
  create_github_environment "$ENVIRONMENT" || { log_error "Failed to set up GitHub environment"; return 1; }
  
  # Set environment name in GitHub variables
  set_github_variable "ENVIRONMENT" "$ENVIRONMENT" "$ENVIRONMENT"
  
  # Step 4: Handle GCP authentication
  check_gcp_auth || { log_error "GCP authentication failed"; return 1; }
  
  # Step 5: Configure GCP region if it doesn't exist in GitHub variables
  set_gcp_region || { log_error "GCP region configuration failed"; return 1; }
  
  # Step 6: Set up VPC/subnet configuration
  scan_and_select_vpc || { log_error "VPC selection failed, GKE needs a VPC to work, please run the script again and choose a VPC option"; return 1; }
  
  if [ "$NETWORKING_OPTION" = "use_existing" ]; then
    scan_and_select_subnet || { log_error "Subnet selection failed, GKE needs a subnet to work with"; return 1; }
  fi
  
  # Step 7: Setup Terraform storage
  setup_terraform_storage || log_warning "Terraform storage setup failed"
  
  # Step 8: Setup GitHub integration with WIF
  if [ -n "$USER_REPO_PATH" ]; then
    setup_github_actions_token || log_warning "GitHub Actions token setup failed"
    create_service_account || log_warning "Service account setup failed"
  fi
  
  # Step 9: Set up labels for resources
  log_info "Setting up resource labels"
  local labels="{\"managed-by\":\"terraform\",\"environment\":\"$ENVIRONMENT\"}"
  set_github_variable "GCP_LABELS" "$labels" "$ENVIRONMENT"
  
  # Step 10: Ask to run infra-ci workflow
  if [ -n "$USER_REPO_PATH" ]; then
    read -e -p "Run infrastructure deployment workflow now? (Y/n): " run_now
    if [[ ! "$run_now" =~ ^[Nn]$ ]]; then
      run_workflow || log_warning "Infrastructure workflow execution failed"
      
      # Step 11: Ask to run app-ci workflow
      read -e -p "Deploy application now? (Y/n): " run_app
      if [[ ! "$run_app" =~ ^[Nn]$ ]]; then
        run_app_workflow || log_warning "Application workflow execution failed"
      else
        echo "→ Skipping application deployment."
      fi
    fi
  fi
  
  log_step "Setup complete"
  log_info "Your GCP deployment environment is ready in $USER_REPO_PATH"
  log_info "Environment: $ENVIRONMENT"
  
  return 0
}

# Execute main only if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi