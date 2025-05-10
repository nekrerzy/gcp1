#!/bin/bash

################################################################################
# GCP Deployment Script
# 
# A modular script for setting up and deploying to Google Cloud Platform
################################################################################

set -e  # Exit on errors

###################### CONFIGURATION AND GLOBALS ###############################

SCRIPT_VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)
CONFIG_YAML="$REPO_ROOT/takeoff_config.yaml"
ENV_FILE="./.env"

# Default settings - can be overridden in config
DEFAULT_GCP_REGION="us-central1"
DEFAULT_GCP_ZONE="us-central1-a"
DEFAULT_NETWORKING_OPTION="create_new"

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
  3. Authenticate with GCP and select/create a project
  4. Select to use an existing VPC or create a new one
  5. Select to use an existing subnet or create a new one
  6. Set up Terraform state storage in GCP
  7. Configure GitHub Actions integration with GCP:
     - Create service account for GitHub Actions
     - Set up Workload Identity Federation (recommended)
     - Configure GitHub repository secrets and variables
  8. Trigger infrastructure deployment workflow
  9. Optionally deploy your application

  PREREQUISITES:
  - GitHub repository with all necessary files
  - A Google account with owner access to GCP
  - Basic understanding of GCP/Terraform resources (recomended)

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

# Call this function immediately after script starts
# Add this line right after the globals section, before the main execution



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
  
  # Format: [command_name]="install_message|install_command"
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

select_user_repository() {
  log_step "Selecting your GitHub repository"
  
  # Get list of repositories the user has access to
  log_info "Fetching your GitHub repositories..."
  USER_REPO_URL=$(git config --get remote.origin.url)
  USER_REPO_PATH=$(gh repo view --json nameWithOwner -q ".nameWithOwner")
  
  
  if [ -z $USER_REPO_URL ] || [ -z $USER_REPO_PATH ]; then
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

set_github_variable() {
  local name="$1"
  local value="$2"
  
  [ -z "$value" ] && { log_debug "Skipping empty $name - nothing to set"; return 0; }
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  [ -z "$GITHUB_TOKEN" ] && export GITHUB_TOKEN=$(gh auth token)
  [ -z "$GITHUB_TOKEN" ] && { log_error "No GitHub token available"; return 1; }
  
  if ! GH_TOKEN="$GITHUB_TOKEN" gh variable set "$name" --body "$value" -R "$USER_REPO_PATH" 2>/dev/null; then
    log_error "Failed to set $name"
    return 1
  fi
  
  log_debug "Set GitHub variable: $name"
  return 0
}

set_github_secret() {
  local name="$1"
  local value="$2"
  
  [ -z "$value" ] && { log_debug "Skipping empty $name - nothing to set"; return 0; }
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  [ -z "$GITHUB_TOKEN" ] && export GITHUB_TOKEN=$(gh auth token)
  [ -z "$GITHUB_TOKEN" ] && { log_error "No GitHub token available"; return 1; }
  
  if ! GH_TOKEN="$GITHUB_TOKEN" gh secret set "$name" -b"$value" -R "$USER_REPO_PATH" 2>/dev/null; then
    log_error "Failed to set secret $name"
    return 1
  fi
  
  log_debug "Set GitHub secret: $name"
  return 0
}

check_github_variable() {
  local var_name="$1"
  
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  [ -z "$GITHUB_TOKEN" ] && export GITHUB_TOKEN=$(gh auth token)
  [ -z "$GITHUB_TOKEN" ] && { log_error "No GitHub token available"; return 1; }
  
  if output=$(GH_TOKEN="$GITHUB_TOKEN" gh variable list -R "$USER_REPO_PATH" 2>&1); then
    echo "$output" | grep -q "^$var_name[[:space:]]" && return 0 || return 1
  else
    log_error "Failed to check variable: $var_name"
    return 1
  fi
}

setup_github_actions_token() {
  log_step "Setting up GitHub Actions token"
  
  # Check GitHub token
  [ -z "$GITHUB_TOKEN" ] && export GITHUB_TOKEN=$(gh auth token)
  [ -z "$GITHUB_TOKEN" ] && { log_error "No GitHub token available"; return 1; }
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  
  # Check if token already exists
  if GH_TOKEN="$GITHUB_TOKEN" gh secret list -R "$USER_REPO_PATH" 2>/dev/null | grep -q "GHACTIONS_TOKEN"; then
    log_info "GHACTIONS_TOKEN already exists"
    return 0
  fi
  
  # Set the token
  log_info "Creating GHACTIONS_TOKEN..."
  if ! GH_TOKEN="$GITHUB_TOKEN" gh secret set GHACTIONS_TOKEN -b"$GITHUB_TOKEN" -R "$USER_REPO_PATH"; then
    log_error "Failed to set GHACTIONS_TOKEN"
    return 1
  fi
  
  log_info "GHACTIONS_TOKEN set successfully"
  return 0
}

sync_github_variables() {
  log_step "Syncing config with GitHub"
  
  # Ensure we have a config and GitHub auth
  [ ! -f "$CONFIG_YAML" ] && { log_error "Config file not found"; return 1; }
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  
  # Map YAML paths to GitHub variables
  declare -A variables=(
    [".gcp.project_id"]="GCP_PROJECT_ID"
    [".gcp.region"]="GCP_REGION"
    [".gcp.zone"]="GCP_ZONE"
    [".environment.networking_option"]="NETWORKING_OPTION"
    [".environment.vpc_name"]="VPC_NAME"
  )
  

  # Set GitHub variables from config
  local success=true
  for yaml_path in "${!variables[@]}"; do
    local var_name="${variables[$yaml_path]}"
    local value=$(yq e "$yaml_path" "$CONFIG_YAML")
    
    if [ "$value" != "null" ] && [ -n "$value" ]; then
      # Always update the variable, even if it already exists
      set_github_variable "$var_name" "$value" || success=false
      log_info "Updated GitHub variable: $var_name with value: $value"
    fi
  done
  
  # Handle labels separately
  local labels=$(yq e '.environment.labels' "$CONFIG_YAML" -o json --indent 0)
  if [ "$labels" != "null" ] && [ -n "$labels" ]; then
    if ! check_github_variable "GCP_LABELS"; then
      set_github_variable "GCP_LABELS" "$labels" || success=false
    else
      log_debug "GCP_LABELS already exists"
    fi
  fi
  
  if [ "$success" = true ]; then
    log_info "GitHub variables synced successfully"
  else
    log_warning "Some GitHub variables failed to sync"
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

###################### CONFIGURATION MANAGEMENT ###############################

create_config_yaml() {
  if [ -f "$CONFIG_YAML" ]; then
    log_info "Config file already exists at $CONFIG_YAML"
    return 0
  fi
  
  log_step "Creating configuration file"
  
  # We already have repository details from GitHub auth
  if [ -z "$USER_REPO_PATH" ]; then
    log_error "No repository selected. Please authenticate with GitHub first."
    return 1
  fi
  
  # Use previously gathered information if available
  local project_id=${GCP_PROJECT:-""}
  local networking_option=${NETWORKING_OPTION:-"$DEFAULT_NETWORKING_OPTION"}
  local vpc_name=${VPC_NAME:-""}
  local subnet_name=${SUBNET_NAME:-""}
  local enviroment=${ENVIRONMENT:-""}
  
  # Get region if not set
  local gcp_region=""
  if [ -n "$TF_VAR_location" ]; then
    gcp_region=$TF_VAR_location
  else
    read -e -p "Enter your desired GCP region (default: $DEFAULT_GCP_REGION): " input_region
    gcp_region=${input_region:-$DEFAULT_GCP_REGION}
  fi
  
  # Get zone if not set
  local gcp_zone=""
  if [ -n "$TF_VAR_zone" ]; then
    gcp_zone=$TF_VAR_zone
  else
    read -e -p "Enter your desired GCP zone (default: $DEFAULT_GCP_ZONE): " input_zone
    gcp_zone=${input_zone:-$DEFAULT_GCP_ZONE}
  fi
  
  # Create config file with gathered values
  mkdir -p $(dirname "$CONFIG_YAML")
  cat > "$CONFIG_YAML" << EOL
# GCP Deployment Configuration

gcp:
  project_id: "$project_id"
  region: "$gcp_region"
  zone: "$gcp_zone"

github:
  repo_name: "$USER_REPO_PATH"

environment:
  env_name: "$enviroment"
  networking_option: "$networking_option"
  vpc_name: "$vpc_name"
  subnet_name: "$subnet_name"
  labels:
    managed-by: "terraform"
    environment: "development"
    team: "platform"
EOL
  
  log_info "Created configuration file at $CONFIG_YAML"
  return 0
}

validate_config() {
  log_step "Validating configuration"
  
  if [ ! -f "$CONFIG_YAML" ]; then
    log_warning "Config file not found"
    
  fi
  sync_github_variables || log_warning "GitHub variable sync failed"
  # Check required fields
  local project_id=$(yq e '.gcp.project_id' "$CONFIG_YAML")
  local region=$(yq e '.gcp.region' "$CONFIG_YAML")
  local zone=$(yq e '.gcp.zone' "$CONFIG_YAML")
  local repo_name=$(yq e '.github.repo_name' "$CONFIG_YAML")
  local networking_option=$(yq e '.environment.networking_option' "$CONFIG_YAML")
  local vpc_name=$(yq e '.environment.vpc_name' "$CONFIG_YAML")
  local subnet_name=$(yq e '.environment.subnet_name' "$CONFIG_YAML")
  local deploy_enviroment=$(yq e '.environment.env_name' "$CONFIG_YAML")
  
  local missing_fields=()
  [ -z "$project_id" ] || [ "$project_id" = "null" ] && missing_fields+=("gcp.project_id")
  [ -z "$region" ] || [ "$region" = "null" ] && missing_fields+=("gcp.region")
  [ -z "$zone" ] || [ "$zone" = "null" ] && missing_fields+=("gcp.zone")
  [ -z "$repo_name" ] || [ "$repo_name" = "null" ] && missing_fields+=("github.repo_name")
  [ -z "$networking_option" ] || [ "$networking_option" = "null" ] && missing_fields+=("environment.networking_option")
  [ -z "$deploy_enviroment" ] || [ "$deploy_enviroment" = "null" ] && missing_fields+=("environment.env_name")
  
  if [ "$networking_option" = "use_existing" ]; then
    if [ -z "$vpc_name" ] || [ "$vpc_name" = "null" ]; then
      missing_fields+=("environment.vpc_name")
    fi
    # We don't require subnet_name as it's optional - can be created by Terraform
  fi
  
  if [ ${#missing_fields[@]} -gt 0 ]; then
    log_warning "Missing required fields in config:"
    for field in "${missing_fields[@]}"; do
      log_warning "  - $field"
    done
    return 1
  fi
  
  log_info "Configuration validated successfully"
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
      
      # Ask about changing projects
      read -e -p "Use a different project? (y/N): " change_project
      if [[ "$change_project" =~ ^[Yy]$ ]]; then
        select_gcp_project || return 1
      else
        export GCP_PROJECT=$current_project
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
    log_info "Set active project to: $selected"
    
    # Update config
    if [ -f "$CONFIG_YAML" ]; then
      yq e -i ".gcp.project_id = \"$selected\"" "$CONFIG_YAML"
      log_debug "Updated project ID in config"
    fi
    
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
    default_name=$(echo "$USER_REPO_PATH" | cut -d'/' -f2)
  else
    default_name="my-gcp-project-$(date +%m%d)"
  fi
  
  read -e -p "Enter new project ID (default: $default_name): " project_id
  project_id=${project_id:-$default_name}
  
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
  
  # Update config if it exists
  if [ -f "$CONFIG_YAML" ]; then
    yq e -i ".gcp.project_id = \"$project_id\"" "$CONFIG_YAML"
    log_debug "Updated project ID in config"
  fi
  
  # Enable required APIs
  log_info "Enabling required APIs..."
  gcloud services enable cloudbuild.googleapis.com \
                       cloudresourcemanager.googleapis.com \
                       iam.googleapis.com \
                       compute.googleapis.com \
                       storage.googleapis.com \
                       
  
  log_info "Project setup complete: $project_id"
  return 0
}

scan_and_select_vpc() {
  log_step "Scanning and selecting VPC"
  
  # Ensure we have a project
  [ -z "$GCP_PROJECT" ] && { log_error "No GCP project set"; return 1; }

  create_config_yaml
  # Update project ID in config
  yq e -i ".gcp.project_id = \"$GCP_PROJECT\"" "$CONFIG_YAML"
  yq e -i ".github.repo_name = \"$USER_REPO_PATH\"" "$CONFIG_YAML"
  yq e -i ".environment.networking_option = \"$NETWORKING_OPTION\"" "$CONFIG_YAML"
  [ -n "$VPC_NAME" ] && yq e -i ".environment.vpc_name = \"$VPC_NAME\"" "$CONFIG_YAML"
  
  
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
      export VPC_NAME="tf_managed_vpc"
      log_info "Set networking option to: create_new"
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
      export VPC_NAME="tf_created_vpc"
      log_info "Set networking option to: create_new"
    elif [ "$vpc_choice" -ge 1 ] && [ "$vpc_choice" -lt "$i" ]; then
      local selected=${vpc_array[$((vpc_choice-1))]}
      export NETWORKING_OPTION="use_existing"
      export VPC_NAME="$selected"
      log_info "Selected VPC: $selected"
      log_info "Set networking option to: use_existing"
    else
      log_error "Invalid selection"
      return 1
    fi
  fi
  
  # Update config file
  if [ -f "$CONFIG_YAML" ]; then
    yq e -i ".environment.networking_option = \"$NETWORKING_OPTION\"" "$CONFIG_YAML"
    [ -n "$VPC_NAME" ] && yq e -i ".environment.vpc_name = \"$VPC_NAME\"" "$CONFIG_YAML"
    log_debug "Updated networking options in config"
  fi
  
  # Set GitHub variables
  if [ -n "$USER_REPO_PATH" ]; then
    set_github_variable "NETWORKING_OPTION" "$NETWORKING_OPTION" || log_warning "Failed to set NETWORKING_OPTION"
    [ -n "$VPC_NAME" ] && set_github_variable "VPC_NAME" "$VPC_NAME" || log_warning "Failed to set VPC_NAME"
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
  
  # Get region from config or use default
  local region=$(yq e '.gcp.region' "$CONFIG_YAML" 2>/dev/null)
  [ -z "$region" ] || [ "$region" = "null" ] && region="$DEFAULT_GCP_REGION"
  
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
          yq e -i ".gcp.region = \"$region\"" "$CONFIG_YAML"
          set_github_variable "GCP_REGION" "$region" || log_warning "Failed to set GCP_REGION"
          log_info "Selected region: $region"
          # Recursive call with new region
          scan_and_select_subnet
          return $?
        else
          log_error "Invalid selection"
          return 1
        fi
      else
        return 1
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
    export SUBNET_NAME=""
    log_info "Terraform will create a new subnet"
  elif [ "$subnet_choice" -ge 1 ] && [ "$subnet_choice" -lt "$i" ]; then
    local selected=${subnet_array[$((subnet_choice-1))]}
    export SUBNET_NAME="$selected"
    log_info "Selected subnet: $selected"
  else
    log_error "Invalid selection"
    return 1
  fi
  
  # Update config file
  if [ -f "$CONFIG_YAML" ]; then
    [ -n "$SUBNET_NAME" ] && yq e -i ".environment.subnet_name = \"$SUBNET_NAME\"" "$CONFIG_YAML"
    log_debug "Updated subnet configuration in config"
  fi
  
  # Set GitHub variables
  if [ -n "$USER_REPO_PATH" ]; then
    [ -n "$SUBNET_NAME" ] && set_github_variable "SUBNET_NAME" "$SUBNET_NAME" || log_warning "Failed to set SUBNET_NAME"
  fi
  
  log_info "Subnet selection complete"
  return 0
}

###################### GCP RESOURCE MANAGEMENT ################################

setup_terraform_storage() {
  log_step "Setting up Terraform storage"
  
  # Ensure we have a project and region
  [ -z "$GCP_PROJECT" ] && { log_error "No GCP project set"; return 1; }
  
  # Get region from config
  local region=$(yq e '.gcp.region' "$CONFIG_YAML")
  [ -z "$region" ] || [ "$region" = "null" ] && region="$DEFAULT_GCP_REGION"
  
  # Check if bucket exists in GitHub variables
  BUCKET_NAME=""
  if [ -n "$USER_REPO_PATH" ] && check_github_variable "BACKEND_STORAGE_ACCOUNT"; then
    BUCKET_NAME=$(gh variable get BACKEND_STORAGE_ACCOUNT -R "$USER_REPO_PATH" 2>/dev/null)
  fi
  
  # Create new bucket name if needed
  if [ -z "$BUCKET_NAME" ]; then
    if [ -n "$USER_REPO_PATH" ]; then
      local repo_short_name=$(echo "$USER_REPO_PATH" | cut -d'/' -f2)
      BUCKET_NAME="${repo_short_name}-tfstate-$GCP_PROJECT"
    else
      BUCKET_NAME="${GCP_PROJECT}-tfstate"
    fi
    log_info "Using bucket name: $BUCKET_NAME"
  fi
  
  
  # Ensure bucket name is lowercase
  BUCKET_NAME=$(echo "$BUCKET_NAME" | tr '[:upper:]' '[:lower:]')

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
  if [ -n "$USER_REPO_PATH" ]; then
    set_github_variable "BACKEND_STORAGE_ACCOUNT" "$BUCKET_NAME" || {
      log_warning "Could not set BACKEND_STORAGE_ACCOUNT variable"
    }
  fi
  
  log_info "Terraform storage setup complete"
  return 0
}

create_service_account() {
  log_step "Creating Service Account for GitHub Actions"
  
  # Ensure we have a project
  [ -z "$GCP_PROJECT" ] && { log_error "No GCP project set"; return 1; }
  [ -z "$USER_REPO_PATH" ] && { log_error "No repository selected"; return 1; }
  
  # Create service account name
  local repo_short_name=$(echo "$USER_REPO_PATH" | cut -d'/' -f2)
  local sa_name="${repo_short_name}-gha"
  local sa_display_name="GitHub Actions for ${repo_short_name}"
  local sa_email="${sa_name}@${GCP_PROJECT}.iam.gserviceaccount.com"
  
  # Check if service account exists
  if gcloud iam service-accounts list --filter="email:$sa_email" | grep -q "$sa_email"; then
    log_info "Service account $sa_email already exists"
  else
    # Create service account
    log_info "Creating service account $sa_name"
    if ! gcloud iam service-accounts create "$sa_name" \
         --display-name="$sa_display_name" \
         --description="Service account for GitHub Actions integration"; then
      log_error "Failed to create service account"
      return 1
    fi
  fi
  sleep 3
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
  gcloud projects add-iam-policy-binding "$GCP_PROJECT" \
    --member="serviceAccount:${sa_email}" \
    --role="$role" \
    --quiet
  done

    
  # Ask user if they want to use Workload Identity Federation (recommended) 
  log_warning "GitHub Actions can authenticate with GCP using Workload Identity Federation "
  read -e -p "Use Workload Identity Federation? (Y/n): " use_wif
  
  if [[ ! "$use_wif" =~ ^[Nn]$ ]]; then
    # Set up Workload Identity Federation
    setup_workload_identity_federation "$sa_email" || return 1
  else
    return 1
  fi
  
  # Set project ID variable
  set_github_variable "GCP_PROJECT_ID" "$GCP_PROJECT"
  
  log_info "Service account setup complete"
  return 0
}

setup_workload_identity_federation() {
  local sa_email="$1"
  local repo_owner=$(echo "$USER_REPO_PATH" | cut -d'/' -f1)
  local repo_name=$(echo "$USER_REPO_PATH" | cut -d'/' -f2)
  
  log_step "Setting up Workload Identity Federation for GitHub Actions"
  
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
  sleep 3
  local pool_list=$(gcloud iam workload-identity-pools list --location="global" --format="value(name)")
  if [ -z "$pool_list" ]; then
    log_error "No workload identity pools found"
    return 1
  fi

  #Use the especifc provider
  PROJECT_NUMBER=$(gcloud projects describe "$GCP_PROJECT" --format="value(projectNumber)")
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
  sleep 3
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
  set_github_variable "WORKLOAD_IDENTITY_PROVIDER" "$provider_name" || log_warning "Failed to set WORKLOAD_IDENTITY_PROVIDER"
  set_github_variable "SERVICE_ACCOUNT" "$sa_email" || log_warning "Failed to set SERVICE_ACCOUNT"
  
  log_info "Workload Identity Federation setup complete"
  log_info "GitHub workflow will use the following configuration:"
  echo -e "Workload Identity Provider: ${CYAN}$provider_name${NC}"
  echo -e "Service Account: ${CYAN}$sa_email${NC}"
  
  return 0
}

###################### MAIN EXECUTION FLOW ###################################

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

# Main function to orchestrate execution
main() {

  display_script_overview
  
  log_step "Starting GCP deployment setup"
  
  # Step 1: Check and install dependencies
  install_dependencies || { log_error "Dependency installation failed"; return 1; }
  

  ##Ask the user what env they want to deploy
  read -e -p "Enter the environment you want to deploy (dev/staging/prod): " ENVIRONMENT
  ENVIRONMENT=${ENVIRONMENT:-dev}
  export ENVIRONMENT
  log_info "Environment set to: $ENVIRONMENT"



  # Step 2: Handle GitHub authentication and repository selection
  check_github_auth || { log_error "GitHub authentication failed"; return 1; }
  
  # Step 3: Handle GCP authentication
  check_gcp_auth || { log_error "GCP authentication failed"; return 1; }
  
  # Step 3.5
  scan_and_select_vpc || { log_error "VPC selection failed, GKE needs a VPC to Work, please run the script again and choose a VPC Option"; return 1; }

  if [ "$NETWORKING_OPTION" = "use_existing" ]; then
    scan_and_select_subnet || { log_error "Subnet selection failed, GKE needs a subnet to work with you can retry by choosing the option Let "Terraform to Create a new VPC" "; return 1; }
  fi

  # Step 4: Setup and validate configuration
  validate_config || { log_warning "Configuration validation failed, continuing anyway"; }
  
  # Step 5: Setup GCP infrastructure
  setup_terraform_storage || log_warning "Terraform storage setup failed"
  
  # Step 6: Setup GitHub integration with WIF
  if [ -n "$USER_REPO_PATH" ]; then
    setup_github_actions_token || log_warning "GitHub Actions token setup failed"
    create_service_account || log_warning "Service account setup failed or canceled"
    sync_github_variables || log_warning "GitHub variable sync failed"
  fi
  
  
  
  # Step 7: Ask to run infra‑ci workflow
  if [ -n "$USER_REPO_PATH" ]; then
    read -e -p "Run deployment workflow now? (Y/n): " run_now
    if [[ ! "$run_now" =~ ^[Nn]$ ]]; then
      run_workflow || log_warning "Infrastructure workflow execution failed"

      # Step 8: Ask to run app‑ci workflow
      read -e -p "Deploy application now with app‑ci workflow? (Y/n): " run_app
      if [[ ! "$run_app" =~ ^[Nn]$ ]]; then
        echo "→ Triggering Application CI/CD workflow…"
        run_app_ci_workflow || log_warning "Application CI/CD workflow execution failed"
      else
        echo "→ Skipping application deployment."
      fi
    fi
  fi

  log_step "Setup complete"
  log_info  "Your GCP deployment environment is ready in $USER_REPO_PATH"

  return 0
}

# Execute main only if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi