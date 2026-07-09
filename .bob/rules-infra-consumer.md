# Infrastructure Consumer Mode Rules

This file provides specific guidance for the Infrastructure Consumer mode when deploying infrastructure using pre-approved Terraform modules.

## Mode Purpose

Help users deploy infrastructure by:
- Discovering available workspaces and modules in HCP Terraform
- Selecting appropriate modules for their cloud provider
- Generating deployment code using private registry modules only
- Ensuring policy compliance before deployment
- Guiding through the deployment process
## CRITICAL: HCP Terraform Workflow

**Terraform operations workflow:**

1. ✅ Run `terraform init` locally FIRST - uploads code to HCP Terraform workspace
2. ✅ Use MCP tools/tfctl for all subsequent operations (create runs, check status, etc.)
3. ❌ DO NOT run `terraform plan` locally - use HCP Terraform runs instead
4. ❌ DO NOT run `terraform apply` locally - use HCP Terraform runs instead
5. ❌ DO NOT use curl or direct API calls to HCP Terraform

**Why:** 
- `terraform init` with HCP Terraform backend uploads code to workspace
- MCP server and tfctl provide full visibility into cost estimation and policy enforcement
- All policy checks happen in HCP Terraform, not locally

## Complete Infrastructure Deployment Workflow (What Bob Does)

When a user asks to deploy infrastructure, Bob MUST guide them through ALL phases:

### Phase 1: Discover Modules
1. Search private registry using MCP tools (`search_private_modules`)
2. Show module details (`get_private_module_details`)
3. Help user select appropriate module

### Phase 2: Generate Deployment Code
1. Create deployment directory structure
2. Generate main.tf with HCP Terraform backend:
   ```hcl
   terraform {
     cloud {
       organization = "your-org"
       workspaces {
         name = "deployment-name"
       }
     }
   }
   ```
3. Use private registry module source
4. Create variables.tf, outputs.tf
5. Include README.md

### Phase 3: Create HCP Terraform Workspace (Bob Initiates)
After generating code, Bob MUST say:
> "Deployment code created! Would you like me to create an HCP Terraform workspace and validate this against policies?"

If user agrees:

1. **Create workspace using MCP tools:**
   ```
   create_workspace
     terraform_org_name: <org-name>
     workspace_name: <deployment-name>
     auto_apply: false
     execution_mode: remote
   ```

2. **Configure workspace variables:**
   ```
   create_workspace_variable
     terraform_org_name: <org-name>
     workspace_name: <deployment-name>
     key: <variable-name>
     value: <variable-value>
     category: terraform
   ```

3. **Upload code to workspace:**
   ```bash
   cd deployments/<deployment-name>
   terraform init
   terraform apply
   ```
   This uploads the code to HCP Terraform workspace. The apply is needed to upload the configuration to HCP Terraform. But the first apply should be cancelled to avoid applying changes.

### Phase 4: Trigger Run and Validate (Bob Initiates)
Bob MUST automatically trigger a run using MCP tools or tfctl:

1. **Create run:**
   ```
   create_run
     terraform_org_name: <org-name>
     workspace_name: <deployment-name>
     message: "Initial deployment validation"
     run_type: plan_only
   ```

2. **Monitor run status:**
   ```
   get_run_details
     run_id: <run-id>
   ```

3. **Show cost estimation** from run details

4. **Show policy results:**
   - ✅ `security-baseline` (hard-mandatory)
   - ✅ `cost-limits` (soft-mandatory)
   - ✅ `module-source-restriction` (hard-mandatory)
   - ℹ️ `aws-resource-types` (advisory)

5. **Explain results** - if policies pass or fail

**Example Complete Interaction:**

```
User: "Deploy an S3 bucket for dev environment"

Bob: [Uses search_private_modules MCP tool]
     "I found the s3-bucket module v1.0.0. Would you like to use it?"

User: "Yes"

Bob: [Generates deployment code with HCP Terraform backend]
     "Deployment code created! Would you like me to create an HCP Terraform workspace and validate this against policies?"

User: "Yes"

Bob: [Uses create_workspace MCP tool]
     [Uses create_workspace_variable MCP tool for each variable]
     [Runs terraform init to upload code]
     [Uses create_run MCP tool]
     [Uses get_run_details MCP tool to monitor]
     
     "✅ Validation complete!
     - HCP Terraform workspace: my-org/s3-bucket-dev
     - Run URL: https://app.terraform.io/app/my-org/workspaces/s3-bucket-dev/runs/run-xxx
     - Cost estimate: $X.XX/month (within budget)
     - All policies passed:
       ✅ security-baseline (hard-mandatory)
       ✅ cost-limits (soft-mandatory)
       ✅ module-source-restriction (hard-mandatory)
     
     Ready to apply? (I can help with that too!)"
```


## Available Skills

- **terraform-style-guide**: Follow HashiCorp's official Terraform style conventions
- **terraform-test**: Write and execute Terraform tests using native testing framework
- **tfctl**: Interact with HCP Terraform / Terraform Cloud using the tfctl CLI (full API coverage)

## Deployment Workflow

### 1. Discovery Phase

Use MCP tools to discover available resources:

```
# List available workspaces
list_workspaces
  terraform_org_name: <org-name>

# Search for private modules
search_private_modules
  terraform_org_name: <org-name>
  search_query: <optional-search-term>

# Get workspace details
get_workspace_details
  terraform_org_name: <org-name>
  workspace_name: <workspace-name>
```

Present 2-4 options to the user with:
- Module name and description
- Cloud provider (AWS, Azure, GCP, IBM Cloud)
- Resource type (compute, storage, network, database, security)
- Estimated cost (if available)
- Compliance status

### 2. Module Selection

Help user choose the right module by asking:
- What cloud provider do you want to use?
- What type of resource do you need?
- What is your use case?
- Any specific requirements (region, size, features)?

### 3. Code Generation

Generate deployment code following terraform-style-guide skill:

**File Structure:**
```
deployments/
  <deployment-name>/
    main.tf           # Module usage
    variables.tf      # Input variables
    outputs.tf        # Output values
    terraform.tfvars  # Variable values (gitignored)
    README.md         # Deployment documentation
```

**Example main.tf:**
```hcl
terraform {
  required_version = ">= 1.14"
  
  cloud {
    organization = "my-org"
    workspaces {
      name = "my-workspace"
    }
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "example" {
  source  = "app.terraform.io/my-org/example/aws"
  version = "1.0.0"
  
  # Required variables
  environment = var.environment
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project_name
  
  # Module-specific variables
  instance_type = var.instance_type
  vpc_id        = var.vpc_id
  subnet_ids    = var.subnet_ids
}
```

### 4. Required Tags (Hard-Mandatory)

ALL deployments MUST include these tags:
- **Environment** (e.g., dev, staging, prod)
- **Owner** (team or individual responsible)
- **CostCenter** (billing allocation)
- **Project** (project identifier)

**Tag Format by Cloud Provider:**

**AWS/Azure:**
```hcl
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Owner       = "platform-team"
    CostCenter  = "engineering"
    Project     = "demo"
  }
}
```

**GCP:**
```hcl
variable "common_labels" {
  description = "Common labels for all resources"
  type        = map(string)
  default = {
    environment = "dev"
    owner       = "platform-team"
    cost_center = "engineering"
    project     = "demo"
  }
}
```

**IBM Cloud:**
```hcl
variable "common_tags" {
  description = "Common tags for all resources"
  type        = list(string)
  default = [
    "Environment:dev",
    "Owner:platform-team",
    "CostCenter:engineering",
    "Project:demo"
  ]
}
```

### 5. Policy Compliance

Before deployment, verify compliance with:

**security-baseline.sentinel (hard-mandatory):**
- Encryption enabled for storage and compute
- Required tags present (Environment, Owner, CostCenter, Project)
- Network isolation configured
- Public access blocked where appropriate

**cost-limits.sentinel (soft-mandatory):**
- Max $100/month cost delta increase
- Max $200/month total cost
- Can be overridden with justification

**module-source-restriction.sentinel (hard-mandatory):**
- Only private registry modules allowed
- Public registry modules (e.g., `terraform-aws-modules/*`) are BLOCKED
- No override possible

### 6. Deployment Process

Guide user through these steps:

**Step 1: Initialize**
```bash
cd deployments/<deployment-name>
terraform init
```

**Step 2: Validate**
```bash
terraform validate
terraform fmt -check
```

**Step 3: Plan**
```bash
terraform plan -out=tfplan
```

**Step 4: Review in HCP Terraform**
- Navigate to HCP Terraform UI
- Review the plan output
- Check Sentinel policy results
- Review cost estimate
- Verify security configurations

**Step 5: Apply (after user confirmation)**
```bash
terraform apply tfplan
```

### 7. Post-Deployment

After successful deployment:
1. Show output values
2. Provide resource access information
3. Document any manual steps required
4. Suggest monitoring and alerting setup

## Tool Selection: MCP Server vs tfctl

**Priority: Always try MCP Server first, use tfctl as fallback**

### Use MCP Server (Primary Tool)
The Terraform MCP server provides high-level, user-friendly tools for common deployment operations:

**Workspace Discovery:**
- ✅ `list_workspaces` - List and filter workspaces
- ✅ `get_workspace_details` - Get workspace configuration

**Module Discovery:**
- ✅ `search_private_modules` - Search private registry modules
- ✅ `get_private_module_details` - Get module documentation and inputs

**Deployment Operations:**
- ✅ `create_run` - Create deployment runs
- ✅ `get_run_details` - Monitor run status
- ✅ `get_plan_details` - Review plan changes
- ✅ `apply_run` - Apply changes (with user confirmation)

**Variable Management:**
- ✅ `list_workspace_variables` - List workspace variables
- ✅ `create_workspace_variable` - Create variables
- ✅ `update_workspace_variable` - Update variables

### Use tfctl (Fallback Tool)
Use tfctl when MCP server doesn't provide the needed functionality:

**Advanced Queries:**
- Complex workspace filtering with `--jq` expressions
- Server-side search with `-f 'search[name]=TERM'`
- Pagination control for large result sets

**Operations Not in MCP:**
- Variable sets (shared variables across workspaces)
- Team access and permissions
- Notification configurations
- State version queries
- Configuration version details
- Organization settings

**Example Decision Flow:**
```
Need to list workspaces?
  → Try: list_workspaces (MCP) ✅
  → If need complex filtering, use: tfctl api /organizations/{org}/workspaces --jq

Need to find workspace by VCS repo?
  → MCP doesn't support VCS filtering
  → Use: tfctl api /organizations/{org}/workspaces --all --jq 'filter by vcs-repo'

Need to create a run?
  → Try: create_run (MCP) ✅
  → If fails, use: tfctl run create WORKSPACE

Need to manage variable sets?
  → MCP doesn't support variable sets
  → Use: tfctl api /organizations/{org}/varsets

Need to check team access?
  → MCP doesn't support team operations
  → Use: tfctl api /team-workspaces
```

## MCP Server Integration

Use MCP server as your primary tool for deployment operations:

### Workspace Management

```
# List workspaces
list_workspaces
  terraform_org_name: <org-name>
  search_query: <optional>
  tags: <optional-comma-separated>

# Get workspace details
get_workspace_details
  terraform_org_name: <org-name>
  workspace_name: <workspace-name>
```

### Module Discovery

```
# Search private modules
search_private_modules
  terraform_org_name: <org-name>
  search_query: <optional>

# Get module details
get_private_module_details
  terraform_org_name: <org-name>
  private_module_id: <namespace/name/provider>
```

### Run Management

```
# Create run
create_run
  terraform_org_name: <org-name>
  workspace_name: <workspace-name>
  message: "Deployment via Bob IDE"

# Get run details
get_run_details
  run_id: <run-id>

# Get plan details
get_plan_details
  plan_id: <plan-id>

# Apply run (requires user confirmation)
apply_run
  run_id: <run-id>
```

### Variable Management

```
# List workspace variables
list_workspace_variables
  terraform_org_name: <org-name>
  workspace_name: <workspace-name>

# Create workspace variable
create_workspace_variable
  terraform_org_name: <org-name>
  workspace_name: <workspace-name>
  key: <variable-name>
  value: <variable-value>
  category: terraform  # or env
  sensitive: false     # or true
```

## tfctl CLI Integration

Use tfctl for direct HCP Terraform operations (see tfctl skill for full details):

**Discovery Operations:**
```bash
# List all workspaces
tfctl api /organizations/{organization}/workspaces --jq '.data[] | {id, name: .attributes.name, terraform_version: .attributes.["terraform-version"]}'

# Search workspaces by name
tfctl api /organizations/{organization}/workspaces -f 'search[name]=TERM' --jq '.data[] | {id, name: .attributes.name}'

# Get workspace details with current run
tfctl api /organizations/{organization}/workspaces/NAME --jq '.data | {id, name: .attributes.name, current_run: .relationships.["current-run"].data}'

# List workspace variables
tfctl api /workspaces/{workspace}/vars -p workspace=NAME --jq '.data[] | {key: .attributes.key, category: .attributes.category, sensitive: .attributes.sensitive}'
```

**Run Operations:**
```bash
# Create a run
tfctl run create WORKSPACE

# Get run status
tfctl run status WORKSPACE

# Get run details
tfctl api /runs/{run-id} --jq '.data | {id, status: .attributes.status, message: .attributes.message}'

# List runs in workspace
tfctl api /workspaces/{workspace}/runs -p workspace=NAME --jq '.data[] | {id, status: .attributes.status, created_at: .attributes.["created-at"]}'
```

**Module Discovery:**
```bash
# List private modules
tfctl api /organizations/{organization}/registry-modules --jq '.data[] | {name: .attributes.name, provider: .attributes.provider, version: .attributes.["version-statuses"][0].version}'

# Search for specific module
tfctl api /organizations/{organization}/registry-modules -f 'search[name]=MODULE_NAME' --jq '.data[] | {name: .attributes.name, provider: .attributes.provider}'
```

**Key tfctl Rules:**
- Always use `--jq '<expr>'` for JSON filtering (never pipe to external jq)
- Use `-p workspace=NAME` to resolve workspace names to IDs automatically
- Workspace-specific paths are `/workspaces/{workspace}/...` not `/organizations/{org}/workspaces/{name}/...`
- Never issue DELETE operations - ask user to run the command manually
- Trust the first answer - don't re-query in different formats

## Multi-Cloud Support

### AWS Resources
- EC2 instances, Auto Scaling Groups
- S3 buckets, EBS volumes, EFS file systems
- RDS databases, DynamoDB tables, ElastiCache
- VPC, subnets, security groups, load balancers
- Lambda functions, ECS/EKS clusters
- IAM roles, KMS keys, Secrets Manager

### Azure Resources
- Virtual Machines, VM Scale Sets
- Storage Accounts, Managed Disks, Azure Files
- SQL Database, Cosmos DB, Redis Cache
- Virtual Networks, NSGs, Load Balancers
- Azure Functions, AKS clusters
- Azure AD, Key Vault

### GCP Resources
- Compute Engine instances, Instance Groups
- Cloud Storage, Persistent Disks, Filestore
- Cloud SQL, Firestore, Memorystore
- VPC, Firewall rules, Cloud Load Balancing
- Cloud Functions, GKE clusters
- IAM, Cloud KMS, Secret Manager

### IBM Cloud Resources
- Virtual Server Instances, Instance Groups
- Cloud Object Storage, Block Storage, File Storage
- Databases for PostgreSQL/MySQL/Redis, Cloudant
- VPC, Security Groups, Load Balancers
- Code Engine, IKS clusters
- IAM, Key Protect, Secrets Manager

## Common Deployment Patterns

### Single Resource Deployment
```hcl
module "storage" {
  source  = "app.terraform.io/my-org/storage/aws"
  version = "1.0.0"
  
  bucket_name = "my-app-data"
  environment = "dev"
  owner       = "platform-team"
  cost_center = "engineering"
  project     = "demo"
}
```

### Multi-Resource Deployment
```hcl
module "network" {
  source  = "app.terraform.io/my-org/vpc/aws"
  version = "1.0.0"
  
  cidr_block  = "10.0.0.0/16"
  environment = "dev"
  owner       = "platform-team"
  cost_center = "engineering"
  project     = "demo"
}

module "compute" {
  source  = "app.terraform.io/my-org/ec2/aws"
  version = "1.0.0"
  
  vpc_id        = module.network.vpc_id
  subnet_ids    = module.network.private_subnet_ids
  instance_type = "t3.medium"
  
  environment = "dev"
  owner       = "platform-team"
  cost_center = "engineering"
  project     = "demo"
}
```

## Error Handling

### Policy Failures

**Hard-Mandatory Policy Failure:**
- Cannot be overridden
- Must fix the issue before proceeding
- Common issues:
  - Missing required tags
  - Missing encryption configuration
  - Using public registry modules
  - Missing separate security resources

**Soft-Mandatory Policy Failure:**
- Can be overridden with justification
- Requires explanation in HCP Terraform UI
- Common issues:
  - Cost exceeds limits
  - Non-standard resource configuration

### Common Issues

1. **Module Not Found**
   - Verify module exists in private registry
   - Check module name format: `namespace/name/provider`
   - Ensure you have access to the module

2. **Authentication Errors**
   - Verify TFE_TOKEN is set correctly
   - Check token has required permissions
   - Ensure token hasn't expired

3. **Variable Errors**
   - Verify all required variables are provided
   - Check variable types match module requirements
   - Ensure sensitive variables are marked correctly

4. **Cost Limit Exceeded**
   - Review resource sizes and quantities
   - Consider using smaller instance types
   - Request cost limit override with justification

## Best Practices

1. **Always use private registry modules** - Public registry is blocked
2. **Include all required tags** - Environment, Owner, CostCenter, Project
3. **Review plan before applying** - Check resources, costs, and policies
4. **Use workspaces for environments** - Separate dev, staging, prod
5. **Document deployments** - Include README with purpose and usage
6. **Test in dev first** - Validate before deploying to production
7. **Monitor costs** - Track spending against limits
8. **Follow security patterns** - Use separate resources for security configs