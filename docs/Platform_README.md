# Azure GenAI Infrastructure Platform Guide

This guide is intended for platform engineers working with the Azure GenAI infrastructure codebase. It covers deployment, configuration, and customization of the infrastructure.

## Repository Structure

```
.
├── infra/
│   ├── env/                   # Environment-specific configurations
│   │   └── dev/               # Development environment
│   │   └── uat/               # UAT environment
│   │   └── prod/              # Production environment
│   └── modules/               # Reusable Terraform modules
├── docs/                      # Documentation
└── .gitignore
```

## Prerequisites

- Azure Subscription with Owner/Contributor access
- Terraform >= 1.0
- Azure CLI >= 2.40
- Git

## Getting Started

1. **Azure Authentication**
   ```bash
   az login
   az account set --subscription <subscription_id>
   ```

2. **Initialize Terraform Backend**
   - Create a storage account for Terraform state
   - Update backend configuration in your environment's backend.tf

3. **Environment Configuration**
   - Copy `env/dev` as a template for new environments
   - Update `variables.tf` with environment-specific values
   - Configure `terraform.tfvars` (not committed to git)

## Deployment Options

### Networking Modes

The infrastructure supports three networking deployment options:
- `create_new`: Creates new VNet and subnets
- `use_existing`: Uses existing network infrastructure
- `no_networking`: Deploys with public endpoints

Configure via `networking_option` variable.

### Resource Tagging

Common tags are defined in `variables.tf`:
```hcl
locals {
  common_tags = {
    Environment = var.environment
    CaseCode    = "a3fb"
    Department  = "aag"
    Owner       = "tsgplatforminfra"
    Tier        = "development"
  }
}
```

## Adding New Environments

1. Create new directory under `env/`
   ```bash
   cp -r infra/env/dev infra/env/prod
   ```

2. Update environment-specific files:
   - `variables.tf`: Update default values
   - `terraform.tfvars`: Configure environment values
   - Update resource SKUs and scaling parameters
   - Adjust networking configuration

3. Configure backend for the new environment:
   ```hcl
   terraform {
     backend "azurerm" {
       resource_group_name  = "<rg-name>"
       storage_account_name = "<storage-name>"
       container_name      = "tfstate"
       key                 = "prod.terraform.tfstate"
     }
   }
   ```

## Module Development

### Creating New Modules

1. Create module structure:
   ```
   modules/new_module/
   ├── main.tf
   ├── variables.tf
   ├── outputs.tf
   └── README.md
   ```

2. Follow module best practices:
   - Accept `tags` variable without defaults
   - Use consistent naming conventions
   - Document all variables and outputs
   - Include usage examples in README.md

### Modifying Existing Modules

1. Version your changes
2. Update module documentation
3. Test in dev environment first
4. Update all environment configurations using the module

## CI/CD Pipeline Setup

### Azure DevOps Pipeline

1. Create service principal for pipeline:
   ```bash
   az ad sp create-for-rbac --name "azure-genai-pipeline" --role Contributor
   ```

2. Configure pipeline variables:
   - AZURE_SUBSCRIPTION_ID
   - AZURE_TENANT_ID
   - AZURE_CLIENT_ID
   - AZURE_CLIENT_SECRET

3. Example pipeline structure:
   ```yaml
   stages:
   - stage: Validate
     jobs:
     - job: terraform_validate
       steps:
       - script: terraform init
       - script: terraform validate

   - stage: Plan
     jobs:
     - job: terraform_plan
       steps:
       - script: terraform plan -out=tfplan

   - stage: Apply
     jobs:
     - job: terraform_apply
       steps:
       - script: terraform apply tfplan
   ```

### Security Considerations

1. Use managed identities where possible
2. Store secrets in Key Vault
3. Enable diagnostic logging
4. Implement least-privilege access
5. Use private endpoints in production

## Common Tasks

### Adding New Services

1. Create or reuse appropriate module
2. Add service configuration to environment
3. Configure networking (private endpoints if needed)
4. Add necessary role assignments
5. Update Key Vault access policies

### Troubleshooting

1. Common issues:
   - Network connectivity
   - Role assignments
   - Key Vault access
   - Resource naming conflicts

2. Debugging steps:
   - Check Azure Activity Log
   - Verify network configuration
   - Validate role assignments
   - Check resource provider registration

## Best Practices

1. **Infrastructure as Code**
   - Use consistent formatting (terraform fmt)
   - Document all changes
   - Use meaningful commit messages
   - Review terraform plan outputs carefully

2. **Resource Naming**
   - Follow naming conventions
   - Use consistent prefixes/suffixes
   - Consider resource name length limits

3. **State Management**
   - Use remote state
   - Implement state locking
   - Backup terraform state
   - Use workspace separation for environments

4. **Security**
   - Implement least privilege
   - Use managed identities
   - Enable encryption at rest
   - Configure network security groups

## Support and Maintenance

1. Regular tasks:
   - Monitor resource usage
   - Review access policies
   - Update terraform providers
   - Rotate credentials

2. Documentation:
   - Keep READMEs updated
   - Document architectural decisions
   - Maintain change logs
   - Update network diagrams

## Contributing

1. Branch naming convention: `feature/`, `bugfix/`, `hotfix/`
2. Create pull requests with:
   - Detailed description
   - terraform plan output
   - Updated documentation
   - Test results

## Contact

For support or questions, contact:
- Platform Team: [Contact Information]
- Security Team: [Contact Information]

## Testing Terraform Configurations

This section provides guidance on testing Terraform configurations both locally and in CI/CD pipelines.

### Local Testing

#### Prerequisites

1. **Required Tools**
   - Terraform CLI (version >= 1.0.0)
   - Azure CLI (latest version)
   - Git
   - Make (optional, for running scripts)

2. **Authentication**
   ```bash
   # Login to Azure
   az login

   # Set the subscription
   az account set --subscription <subscription_id>
   ```

3. **Environment Setup**
   ```bash
   # Clone the repository
   git clone https://github.com/your-org/ais-azure-genai-iac.git
   cd ais-azure-genai-iac

   # Navigate to the environment directory
   cd infra/env/dev
   ```

#### Testing Workflow

1. **Initialize Terraform**
   ```bash
   terraform init
   ```

2. **Validate Configuration**
   ```bash
   terraform validate
   ```

3. **Run Terraform Plan**
   ```bash
   # Basic plan
   terraform plan -out=tfplan

   # Plan with variable file
   terraform plan -var-file=dev.tfvars -out=tfplan

   # Plan with specific targets
   terraform plan -target=module.openai -out=tfplan
   ```

4. **Review the Plan**
   ```bash
   # View the plan in human-readable format
   terraform show tfplan
   ```

5. **Apply Changes (if needed)**
   ```bash
   terraform apply tfplan
   ```

6. **Clean Up (if needed)**
   ```bash
   terraform destroy
   ```

#### Best Practices for Local Testing

1. **Use Workspaces**
   ```bash
   # Create a personal workspace to avoid conflicts
   terraform workspace new <your-name>

   # Select your workspace
   terraform workspace select <your-name>
   ```

2. **Use Variable Files**
   Create a personal `.tfvars` file (e.g., `dev.johndoe.tfvars`) and use it for testing:
   ```bash
   terraform plan -var-file=dev.johndoe.tfvars
   ```

3. **Limit Scope**
   Use `-target` to limit the scope of your changes:
   ```bash
   terraform plan -target=module.openai -out=tfplan
   ```

4. **Mock External Dependencies**
   For modules that depend on external resources, use mock data sources or create minimal test resources.

#### Deploying from local machine
In scenarios where target state tooling for IaC deployments is not setup yet or there is a need for 1-2 engineers to rapidly iterate towards a relatively stable infrastruture, the following can help deploy from local.

1. **Update provider configuration**
Remove the below configuration from all declarations in `providers.tf`

```hcl
tenant_id       = var.tenant_id
client_id       = var.client_id
use_oidc        = true
```

2. **Authenticate with azure cli**
```bash
az login
az account set --subscription <subscription_id>
```
3. **Run the following commands from the terraform directory**
```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### CI/CD Pipeline Testing

Our CI/CD pipeline automatically tests Terraform configurations when changes are pushed to the repository.

#### Pipeline Workflow

1. **Pull Request Validation**
   - Runs `terraform init` and `terraform validate`
   - Performs `terraform plan` and posts the plan as a comment on the PR
   - Runs static code analysis with TFLint
   - Checks for security issues with Checkov or tfsec

2. **Merge to Main Branch**
   - Runs the same validation steps
   - Applies changes to the development environment
   - Runs post-deployment tests

3. **Promotion to Higher Environments**
   - Manual approval required
   - Applies the same configuration with environment-specific variables

#### CI/CD Configuration

The pipeline is configured in `.github/workflows/terraform.yml` or `azure-pipelines.yml` depending on your CI/CD platform.

Example GitHub Actions workflow:
```yaml
name: 'Terraform CI/CD'

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v1
    - name: Terraform Init
      run: terraform init
      working-directory: ./infra/env/dev
    - name: Terraform Validate
      run: terraform validate
      working-directory: ./infra/env/dev
    - name: Terraform Plan
      run: terraform plan -no-color
      working-directory: ./infra/env/dev
      env:
        ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
        ARM_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
        ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
```

#### Authentication in CI/CD

The pipeline uses service principal authentication:

```hcl
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}
```

These values are stored as secrets in your CI/CD platform and injected as environment variables.

### Differences Between Local and CI/CD Testing

| Aspect | Local Testing | CI/CD Pipeline |
|--------|--------------|----------------|
| Authentication | Interactive login (az login) | Service Principal |
| State Storage | Local or remote | Always remote |
| Variable Files | Personal .tfvars files | Environment-specific variables |
| Approval Process | None | Manual approvals for production |
| Scope | Can target specific resources | Always full environment |
| Parallelism | Default (10) | Higher (can be configured) |
| Logging | Standard output | Captured in CI/CD logs |

### Troubleshooting

#### Common Local Testing Issues

1. **Authentication Errors**
   ```
   Error: Error building AzureRM Client: obtain subscription() from Azure CLI: Error parsing json result from the Azure CLI: Error waiting for the Azure CLI: exit status 1
   ```
   Solution: Run `az login` again or check your Azure CLI installation.

2. **State Lock Issues**
   ```
   Error: Error acquiring the state lock: state lock acquisition timed out
   ```
   Solution: If you're sure no other process is running, remove the lock:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

3. **Module Source Issues**
   ```
   Error: Module not found
   ```
   Solution: Check module paths and run `terraform init` again.

#### Common CI/CD Issues

1. **Credential Issues**
   - Verify service principal has correct permissions
   - Check that secrets are correctly configured in CI/CD platform

2. **Timeout Issues**
   - Increase timeout limits for complex deployments
   - Consider breaking down large deployments into smaller chunks

3. **Concurrent Deployment Conflicts**
   - Implement queue management in your CI/CD pipeline
   - Use separate state files for different environments

### Best Practices

1. **Always run `terraform plan` before applying changes**
2. **Use consistent Terraform versions across local and CI/CD environments**
3. **Store state remotely with locking enabled**
4. **Use consistent formatting with `terraform fmt`**
5. **Document all variables and outputs**
6. **Implement automated testing for Terraform modules**
7. **Use separate workspaces or state files for testing**
8. **Review plans carefully before applying**

## Terraform State Management

This project uses Azure Storage for managing Terraform state files, providing a secure and collaborative approach to infrastructure state management.

### Backend Configuration

The Terraform backend is configured in `infra/env/dev/providers.tf` to use Azure Storage:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.5"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
  backend "azurerm" {}
}
```

The actual backend configuration values are provided at initialization time using a backend configuration file or command-line parameters.

### Remote State Access

The infrastructure is designed to access its own remote state when needed:

```hcl
data "terraform_remote_state" "backend" {
  backend = "azurerm"
  config = {
    storage_account_name = var.backend_storage_account
    container_name      = var.backend_container
    key                = "${var.unique_suffix}.tfstate"
    subscription_id    = var.subscription_id
    tenant_id         = var.tenant_id
    client_id         = var.client_id
    use_oidc          = true
    resource_group_name = var.resource_group_name
  }
}
```

### Setting Up the Backend

#### Prerequisites

1. An Azure Storage Account
2. A container within the storage account
3. Appropriate access permissions

#### Initialization

To initialize Terraform with the Azure backend, create a `backend.tfvars` file with the following content:

```hcl
resource_group_name  = "your-resource-group"
storage_account_name = "your-storage-account"
container_name       = "your-container"
key                  = "your-environment.tfstate"
subscription_id      = "your-subscription-id"
tenant_id            = "your-tenant-id"
```

Then initialize Terraform with:

```bash
terraform init -backend-config=backend.tfvars
```

#### Environment-Specific State Files

Each environment (dev, uat, prod) should use a separate state file by specifying a different `key` value:

```
key = "dev.tfstate"    # For development
key = "uat.tfstate"    # For UAT
key = "prod.tfstate"   # For production
```

### State Management Best Practices

1. **Never Manually Edit State Files**
   - Always use Terraform commands to manipulate state

2. **Use State Locking**
   - Azure Storage automatically provides state locking to prevent concurrent modifications

3. **Backup State Files**
   - Enable versioning on the Azure Storage container
   - Consider periodic backups of the state files

4. **Secure Access to State**
   - Restrict access to the storage account using Azure RBAC
   - Consider using Private Endpoints for the storage account
   - Encrypt state files at rest

5. **State File Isolation**
   - Use separate state files for different environments
   - Consider using workspaces for developer-specific testing

### Handling State in CI/CD

In CI/CD pipelines, the backend configuration is provided through environment variables or pipeline variables:

```yaml
- name: Terraform Init
  run: terraform init \
    -backend-config="resource_group_name=$TF_RESOURCE_GROUP" \
    -backend-config="storage_account_name=$TF_STORAGE_ACCOUNT" \
    -backend-config="container_name=$TF_CONTAINER_NAME" \
    -backend-config="key=$TF_STATE_KEY" \
    -backend-config="subscription_id=$ARM_SUBSCRIPTION_ID" \
    -backend-config="tenant_id=$ARM_TENANT_ID" \
    -backend-config="client_id=$ARM_CLIENT_ID" \
    -backend-config="use_oidc=true"
  env:
    TF_RESOURCE_GROUP: ${{ secrets.TF_RESOURCE_GROUP }}
    TF_STORAGE_ACCOUNT: ${{ secrets.TF_STORAGE_ACCOUNT }}
    TF_CONTAINER_NAME: ${{ secrets.TF_CONTAINER_NAME }}
    TF_STATE_KEY: ${{ env.ENVIRONMENT }}.tfstate
    ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
    ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
```

### Troubleshooting State Issues

1. **State Locking Timeout**
   ```
   Error: Error acquiring the state lock: state lock acquisition timed out
   ```
   Solution: Check if another process is running or force-unlock if necessary:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

2. **Authentication Failures**
   ```
   Error: Failed to get existing workspaces: storage: service returned error: StatusCode=403
   ```
   Solution: Verify your authentication credentials and permissions.

3. **State File Not Found**
   ```
   Error: Failed to get existing workspaces: storage: service returned error: StatusCode=404
   ```
   Solution: Verify the storage account, container, and key path exist.

4. **State Migration**
   If you need to migrate from local state to remote state:
   ```bash
   terraform state push terraform.tfstate
   ```

### Accessing Outputs from Other State Files

To access outputs from another state file:

```hcl
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = "your-resource-group"
    storage_account_name = "your-storage-account"
    container_name       = "your-container"
    key                  = "network.tfstate"
    subscription_id      = var.subscription_id
    tenant_id            = var.tenant_id
    client_id            = var.client_id
    use_oidc             = true
  }
}

# Access an output from the remote state
resource "azurerm_subnet" "example" {
  name                 = "example-subnet"
  resource_group_name  = data.terraform_remote_state.network.outputs.resource_group_name
  virtual_network_name = data.terraform_remote_state.network.outputs.virtual_network_name
  address_prefixes     = ["10.0.1.0/24"]
}
