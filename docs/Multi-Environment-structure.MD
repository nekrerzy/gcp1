# Multi-Environment Infrastructure as Code Pipeline with GitHub Actions

## Why Built this Multi-Environment Infrastructure Pipeline

When developing software, keeping our development, staging, and production environments organized and separated is crucial. Each environment has a distinct purpose: development for experimentation, staging for testing, and production for live users. Managing these manually can quickly become overwhelming, error-prone, and inefficient.

To address this, we adopted a structured approach using Infrastructure as Code (IaC) integrated with GitHub Actions. This setup helps us automate infrastructure deployment, significantly reducing human error and streamlining the process.

At the core of our solution are GitHub Environments. These special areas within GitHub that allow us to clearly separate and secure our development, staging, and production configurations. Each environment can safely store sensitive information such as credentials and configuration details, ensuring they're accessible only to authorized workflows and team members.

We also created a simple yet powerful setup script (takeoff.sh). This script makes it easy to prepare each environment, handling everything from creating necessary cloud resources to setting up GitHub integration. Instead of manually repeating the setup for each environment, developers run this script, which ensures consistency and saves valuable time.

Our Continuous Integration and Continuous Deployment (CI/CD) pipeline further enhances this workflow. Using GitHub Actions (infra-ci.yml), every change we make to the infrastructure code can be automatically tested, validated, and deployed. This means fewer manual deployments, faster turnaround times, and a more reliable release process.

With this approach, our infrastructure management is not only efficient and reliable but also scalable and portable. Whether we need to adjust for growth or adapt to new cloud providers, the goals remain consistent, enabling smooth transitions and stable operations.


Here we outline the use of the deployment strategy using GitHub Actions and environments, with appropriate separation of concerns.


![Architecture](/docs/ghenvs.png)


## Architecture Overview

The architecture consists of two main components:

1. **Setup Script (`takeoff.sh`)** - A bootstrapping utility that configures all necessary resources, authentication, and permissions.
2. **CI/CD Pipeline (`infra-ci.yml`)** - A GitHub Actions workflow that automates infrastructure deployment with environment-specific configurations.

This combination creates a complete solution for managing cloud infrastructure that is:

- **Multi-environment** - Supports separate dev, staging, and production environments
- **Automated** - Reduces manual intervention and human error
- **Scalable** - Works for small and big deployments
- **Portable** - Can be adapted to work with any major cloud provider

## GitHub Environments - The Foundation

GitHub Environments are the foundation of this architecture, providing:

1. **Logical Separation** - Clear boundaries between development, staging, and production
2. **Scoped Secrets** - Environment-specific credentials and sensitive values
3. **Scoped Variables** - Configuration values specific to each environment

GitHub Environments operate by defining specific areas within your repository, each tied to unique configurations, secrets, and protection rules. This makes it simple to manage access and deploy workflows targeted specifically to an environment. 


### How GitHub Environments Are Used

The system leverages GitHub Environments in several key ways:

1. **Environment Creation**
   - Environments are created programmatically via the GitHub API
   - Each environment development, staging, and production is established and may include optional protection rules.

2. **Environment Variables**
   - Cloud-specific configuration (project IDs, regions, networking details, etc.)
   - Resource naming and identification
   - Feature flags and environment-specific toggles

3. **Environment Secrets**
   - Service account credentials
   - API keys and tokens
   - Other sensitive values


## The Setup Process

The setup script automates the following process:

1. **Environment Selection**
   - Choose which environment to configure (dev, staging, prod)
   - Create the GitHub Environment if it doesn't exist

```
read -e -p "Enter the environment you want to deploy (dev/staging/prod) [default: dev]: " input_env
  ENVIRONMENT=${input_env:-$DEFAULT_ENV}
  export ENVIRONMENT
```

2. **Resource Provisioning**
   - Create the enviroment in GitHub
   - Configure environment-specific resources (e.g., VPCs, subnets, backend buckets)

```
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
    
    return 0
  else
    log_error "Failed to create GitHub environment: $env_name"
    return 1
  fi
}
```


1. **GitHub Integration**
   - Store all necessary variables and secrets in the GitHub Environment
   - Configure the repository for CI/CD integration
   

```
set_github_variable() {
  local var_name="$1"
  local var_value="$2"
  local env_name="$3"  
  
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

```




## The CI/CD Pipeline

The infrastructure CI/CD pipeline provides a complete workflow for deploying infrastructure:

### Workflow Triggers

The pipeline can be triggered through:
- **Manual execution** with environment selection

```
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - prod
          - staging

```

- **Push to main branch** (typically updates development)
- **Version tags** (typically updates production)
- **File path changes** in infrastructure code

### Environment Determination


The pipeline automatically determines which environment to target based on:
- The trigger type (manual, push, tag)
- The branch or tag name
- Manual selection in case of manual triggers

```
jobs:
  determine-environment:
    runs-on: ubuntu-latest
    outputs:
      environment: ${{ steps.set-env.outputs.environment }}
    steps:
      - id: set-env
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "environment=dev" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref }}" == refs/tags/* && "${{ github.ref }}" == *[Vv]* ]]; then
            echo "environment=prod" >> $GITHUB_OUTPUT
          else
            echo "environment=dev" >> $GITHUB_OUTPUT  # Default fallback
          fi

```

# Environment Deploy Strategies ( To be decided )

## Option 1. Long-Lived Branch per Environment 



### How it works
* You maintain one branch per environment (e.g. `main`→dev, `staging`, `prod` ).
* Your CI/CD pipeline triggers Terraform plans/applies when changes land on each branch.
* Promotion happens via Git merges: e.g. PR into `staging`, then into `prod`.

### Pros
*  Clear "promotion" flow: you can gate each merge with reviews/tests.
*  Environment-specific drift is easy to spot—each branch has its own state.

### Cons
*  Merge overhead and potential conflicts as branches diverge.
*  Risk of "branch rot" if fixes on prod aren't back-merged.

## Option 2. Folder-Per-Environment

### How it works

```
└─ infra/
   ├─ modules/    ← shared modules
   ├─ envs/
      ├─ dev/
      │  ├─ main.tf
      │  └─ terraform.tfvars
      ├─ staging/
      └─ prod/
```

* Each env directory calls the same modules but uses its own tfvars and backend.
* CI/CD picks up changes in a given folder.

### Pros
*  Maximum isolation: state, variables, even provider setups are fully separate.
*  Teams can own a single env folder without touching others.

### Cons
*  Some duplication of provider/block code.
*  Changes to module versions must be propagated manually to each folder.

## Option 3. Use of 1 Folder with multiple tfvars files
### How it works

```
└─ infra/
   ├─ modules/    ← shared modules
   ├─ envs/
      ├─ resource.tf
      ├─ terraform.tfvars
      ├─ dev.tfvars
      ├─ staging.tfvars
      └─ prod.tfvars
```
* All environments share the same folder but use different tfvars files.

### Usage

* The pipeline uses the `terraform.tfvars` file for the default environment and the specific tfvars file for the selected environment.


### Post-Deployment Configuration

After infrastructure is provisioned, the pipeline:
**Captures outputs** as GitHub Environment variables folloing the same logic and saving new infra environment variables in the apropriate GH environment

```
- name: Capture Terraform Outputs
      if: success()
      run: |
        CURRENT_ENV="${{ needs.determine-environment.outputs.environment }}"

        # Project info
        gh variable set PROJECT_NUMBER --env $CURRENT_ENV --body "$(terraform output -raw project_number)"

        # Artifact repository
        gh variable set ARTIFACT_REPOSITORY_URL --env $CURRENT_ENV --body "$(terraform output -raw repository_url)"
        gh variable set Docker_IMAGE_PATH --env $CURRENT_ENV --body "$(terraform output -raw docker_image_path)"
        .....
```

## Terraform Integration

The pipeline integrates with Terraform to manage cloud resources. The Terraform code is organized in a modular structure, allowing for easy reuse and management of resources across environments.


This multi-environment deployment solution provides a robust foundation for managing cloud resources across development, staging, and production environments. By leveraging GitHub Environments and Actions, it creates a secure, automated, and scalable approach to infrastructure management.

The architecture can be adapted to any cloud provider while maintaining the core principles of:
- Environment separation
- Secure authentication
- Automated deployment
- Infrastructure as code

By following this approach, our goal is to achieve consistent, repeatable infrastructure deployments.