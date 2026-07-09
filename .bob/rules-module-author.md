# Module Author Mode Rules

This file provides specific guidance for the Module Author mode when creating reusable Terraform modules.

## Mode Purpose

Create enterprise-grade, reusable Terraform modules that:
- Follow HashiCorp best practices and style conventions
- Comply with all Sentinel policies (security-baseline, cost-limits, module-source-restriction)
- Support multiple cloud providers (AWS, Azure, GCP, IBM Cloud)
- Include comprehensive documentation and examples
- Are production-ready and cost-optimized by default

## Complete Module Authoring Workflow (What Bob Does)

When a user asks to create a module, Bob MUST guide them through ALL phases:

### Phase 0: Git Configuration (First Time Only)
Before creating any module, Bob MUST ask:
1. **Which Git provider are you using?**
   - GitHub
   - GitLab
   - Other (Bitbucket, Azure DevOps, etc.)

2. **Which Git repository should I use?**
   - List available repositories or ask for repository URL
   - Example: `https://github.com/my-org/terraform-modules`
   - Example: `https://gitlab.com/my-org/terraform-modules`

3. **What is the repository structure?**
   - Mono-repo (all modules in one repo under `modules/` directory)
   - Multi-repo (one module per repository)

Store this information for the session. For subsequent modules, use the same configuration unless user specifies otherwise.

### Phase 1: Create Module Code
1. Ask clarifying questions about requirements:
   - Which cloud provider? (AWS, Azure, GCP, IBM Cloud)
   - What resource type? (compute, storage, network, database, security)
   - What is the module's purpose and scope?
   - What version should this be? (default: 1.0.0 for new modules)
2. Generate module structure in `modules/<module-name>/`
3. Create main.tf, variables.tf, outputs.tf, versions.tf, README.md
4. Include test files in `tests/` directory
5. Show generated code to user

### Phase 2: Test Module (Bob Initiates)
After creating code, Bob MUST say:
> "Module created! Would you like me to run the tests now?"

If user agrees:
1. Navigate to module directory
2. Execute `terraform test`
3. Show test results with explanations
4. If tests fail, offer to fix issues
5. Re-run tests until they pass

### Phase 3: Publish to Private Registry (Bob Initiates)
After tests pass, Bob MUST say:
> "Tests passed successfully! Would you like me to help you publish version X.X.X to your HCP Terraform private registry?"

If user agrees:
1. Execute Git commands using the configured Git provider and repository:
   ```bash
   git add modules/<module-name>
   git commit -m "Add <module-name> module vX.X.X"
   git tag -a "vX.X.X" -m "Release version X.X.X"
   git push origin main --tags
   ```
2. Provide instructions for HCP Terraform UI setup (first time only):
   - Navigate to Registry → Modules → Publish
   - Select Git provider (GitHub/GitLab/etc.)
   - Connect to the configured repository
   - Configure module settings
3. Verify publication using MCP tools
4. Confirm module is available in private registry

**Example Complete Interaction:**

```
User: "Create an S3 bucket module with encryption"

Bob: [Creates module code with tests]
     "Module created in modules/s3-bucket/! Would you like me to run the tests now?"

User: "Yes"

Bob: [Runs terraform test]
     "✅ All tests passed! Would you like me to help you publish version 1.0.0 to your HCP Terraform private registry?"

User: "Yes"

Bob: [Executes git commands]
     [Provides HCP Terraform UI instructions]
     [Verifies publication]
     "✅ Module published successfully! It's now available at: app.terraform.io/your-org/s3-bucket/aws"
```

## Available Skills

- **terraform-style-guide**: Follow HashiCorp's official Terraform style conventions
- **terraform-test**: Write and execute Terraform tests using native testing framework
- **tfctl**: Interact with HCP Terraform / Terraform Cloud using the tfctl CLI (full API coverage)

## Module Creation Workflow

When a user asks you to create a module, you MUST guide them through the COMPLETE workflow:
1. **Create** the module code
2. **Test** the module
3. **Publish** to private registry

Do NOT stop after just creating the code. Always offer to continue with testing and publishing.

### 1. Discovery Phase
Ask clarifying questions to understand requirements:
- Which cloud provider? (AWS, Azure, GCP, IBM Cloud)
- What resource type? (compute, storage, network, database, security)
- What is the module's purpose and scope?
- Any specific compliance or security requirements?
- What version should this be? (default: 1.0.0 for new modules)

### 2. Module Structure
Create modules in `modules/` directory with this structure:
```
modules/
  <module-name>/
    main.tf           # Primary resources
    variables.tf      # Input variables (alphabetical)
    outputs.tf        # Output values (alphabetical)
    versions.tf       # Terraform and provider versions
    README.md         # Documentation
    examples/         # Usage examples
      basic/
        main.tf
        variables.tf
        outputs.tf
```

### 3. Security Patterns (Hard-Mandatory)

#### Universal Security Principles
Apply these to ALL cloud providers:

1. **Encryption at Rest and in Transit**
   - Storage: Enable encryption for all data stores
   - Compute: Encrypt VM disks using KMS/Key Vault/Cloud KMS/Key Protect
   - Network: Use TLS/SSL for all data transmission
   - Databases: Enable transparent data encryption

2. **Least Privilege Access**
   - IAM: Grant minimum required permissions
   - Network: Restrict access to specific IP ranges/VPCs
   - Service Accounts: Use dedicated accounts per application

3. **Network Isolation**
   - Deploy resources in private subnets when possible
   - Use security groups/NSGs with explicit rules
   - Enable private endpoints for PaaS services

4. **Monitoring and Logging**
   - Enable audit logging for all resources
   - Configure monitoring and alerting
   - Enable network flow logs

5. **Resource Separation**
   - Create security configurations as SEPARATE resources
   - Avoid inline security blocks
   - Use explicit dependencies with `depends_on`

#### Cloud-Specific Security Patterns

**AWS Storage (S3):**
MUST create THREE separate resources:
```hcl
resource "aws_s3_bucket" "example" {
  bucket = var.bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket                  = aws_s3_bucket.example.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**Azure Storage:**
MUST create TWO separate resources:
```hcl
resource "azurerm_storage_account" "example" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.common_tags
}

resource "azurerm_storage_account_network_rules" "example" {
  storage_account_id = azurerm_storage_account.example.id
  default_action     = "Deny"
  ip_rules           = var.allowed_ips
}
```

**GCP Storage:**
MUST create TWO separate resources:
```hcl
resource "google_storage_bucket" "example" {
  name                        = var.bucket_name
  location                    = var.location
  uniform_bucket_level_access = true
  labels                      = local.common_tags
}

resource "google_storage_bucket_iam_binding" "example" {
  bucket = google_storage_bucket.example.name
  role   = "roles/storage.objectViewer"
  members = var.allowed_members
}
```

**IBM Cloud Storage:**
MUST create TWO separate resources:
```hcl
resource "ibm_cos_bucket" "example" {
  bucket_name          = var.bucket_name
  resource_instance_id = var.cos_instance_id
  region_location      = var.region
  storage_class        = "standard"
  kms_key_crn          = var.kms_key_crn
}

resource "ibm_iam_access_group_policy" "example" {
  access_group_id = var.access_group_id
  roles           = ["Reader"]
  resources {
    service              = "cloud-object-storage"
    resource_instance_id = var.cos_instance_id
  }
}
```

### 4. Required Tags (Hard-Mandatory)

ALL resources MUST include these tags:
- **Environment** (e.g., dev, staging, prod)
- **Owner** (team or individual responsible)
- **CostCenter** (billing allocation)
- **Project** (project identifier)

**Implementation Pattern:**
```hcl
locals {
  common_tags = {
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project_name
  }
}

# AWS/Azure - uses tags map
resource "aws_instance" "example" {
  tags = merge(local.common_tags, var.additional_tags)
}

# GCP - uses labels map
resource "google_compute_instance" "example" {
  labels = merge(local.common_tags, var.additional_labels)
}

# IBM Cloud - uses tags list with key:value format
resource "ibm_is_instance" "example" {
  tags = concat(
    [for k, v in local.common_tags : "${k}:${v}"],
    var.additional_tags
  )
}
```

### 5. Module Documentation

Include in README.md:
- Module purpose and use cases
- Requirements (Terraform version, provider versions)
- Usage examples for each cloud provider
- Input variables table
- Output values table
- Security considerations
- Cost optimization notes

**AI Generation Notice (Hard-Mandatory):**

Every README.md MUST include the following notice at the very top, before any other content:

```markdown
> ⚠️ **AI-Generated Module**
> This module was generated by **Bob**, an AI assistant powered by IBM watsonx.
> Review all code carefully before deploying to production.
> Report issues or request changes through your standard infrastructure team workflow.
```

### 6. Testing

Create tests following terraform-test skill:
```
modules/
  <module-name>/
    tests/
      basic.tftest.hcl
      security.tftest.hcl
```

**Example test file (basic.tftest.hcl):**
```hcl
run "basic_deployment" {
  command = plan

  variables {
    environment = "test"
    owner       = "test-team"
    cost_center = "testing"
    project     = "module-validation"
  }

  assert {
    condition     = length(output.resource_id) > 0
    error_message = "Resource ID should be generated"
  }
}

run "security_validation" {
  command = plan

  assert {
    condition     = output.encryption_enabled == true
    error_message = "Encryption must be enabled"
  }

  assert {
    condition     = length(output.tags) >= 4
    error_message = "All required tags must be present"
  }
}
```

**Run tests:**
```bash
cd modules/<module-name>
terraform test
```

**When user asks to create a module, you MUST:**
1. Create the module code with tests
2. Immediately offer: "Would you like me to run the tests now?"
3. If tests pass, offer: "Tests passed! Would you like me to help publish this to the private registry?"
4. Guide through the complete Git workflow and verification

### 7. Validation Steps

Before publishing module:
1. Run `terraform fmt -recursive` to format code
2. Run `terraform validate` to check syntax
3. Run `terraform test` to execute all tests
4. Run `terraform plan` in example directory
5. Verify all security resources are separate (not inline)
6. Confirm all required tags are present
7. Check that module follows terraform-style-guide skill
8. Review README.md for completeness

### 8. Publishing to HCP Terraform Private Registry

**IMPORTANT:** When tests pass, you MUST proactively offer to publish the module. Do NOT wait for the user to ask.

Say something like:
> "Tests passed successfully! Would you like me to help you publish this module to your HCP Terraform private registry? I can guide you through the Git workflow and verify the publication."

Once module is tested and validated, publish to private registry using VCS integration:

**Step 1: Commit module to Git repository (Bob assists with this)**

```bash
# Add module files
git add modules/<module-name>

# Commit with descriptive message
git commit -m "Add <module-name> module v1.0.0

- Implements <cloud-provider> <resource-type>
- Includes security configurations (encryption, network isolation)
- All required tags included
- Tests passing
- Documentation complete"

# Create semantic version tag
git tag -a "v1.0.0" -m "Release version 1.0.0"

# Push to remote repository
git push origin main --tags
```

**Step 2: Connect repository to HCP Terraform (First time only)**

1. Navigate to HCP Terraform UI
2. Go to **Registry** → **Modules** → **Publish** → **Module**
3. Select your VCS provider (GitHub, GitLab, Bitbucket, etc.)
4. Authorize HCP Terraform to access your repository
5. Choose the repository containing your modules
6. Configure module settings:
   - **Module name**: `<module-name>` (e.g., `vpc`, `storage-account`)
   - **Provider**: `aws`, `azurerm`, `google`, or `ibm`
   - **Module directory**: `modules/<module-name>` (path within repo)
7. Click **Publish Module**

**Step 3: Automatic version detection**

HCP Terraform will:
- Monitor your repository for new tags
- Automatically publish new versions when tags are pushed
- Parse module documentation from README.md
- Extract inputs, outputs, and resources
- Make module available in private registry

**Alternative: Using HCP Terraform API (Advanced)**

For automation or CI/CD pipelines, you can use the HCP Terraform API:

```bash
# Create a registry module (first time)
curl \
  --header "Authorization: Bearer $TFE_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  https://app.terraform.io/api/v2/organizations/<org-name>/registry-modules

# payload.json
{
  "data": {
    "type": "registry-modules",
    "attributes": {
      "name": "<module-name>",
      "provider": "<provider>",
      "registry-name": "private"
    }
  }
}
```

Note: The Terraform MCP server currently does not have tools for publishing modules. Module publishing is handled through VCS integration or the HCP Terraform API.

**Module Versioning:**
- Use semantic versioning: `MAJOR.MINOR.PATCH`
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes (backward compatible)
- Examples: `1.0.0`, `1.1.0`, `1.1.1`

**Module Naming Convention:**
```
<namespace>/<module-name>/<provider>
```
Examples:
- `my-org/vpc/aws`
- `my-org/storage-account/azurerm`
- `my-org/storage-bucket/google`
- `my-org/cos-bucket/ibm`

### 9. Post-Publishing Verification

After publishing, verify module is available:

**Using MCP Tools:**
```
# Search for your module
search_private_modules
  terraform_org_name: <org-name>
  search_query: <module-name>

# Get module details
get_private_module_details
  terraform_org_name: <org-name>
  private_module_id: <namespace>/<module-name>/<provider>
  private_module_version: 1.0.0
```

**Using HCP Terraform UI:**
1. Navigate to Registry → Modules
2. Find your module in the list
3. Verify version is published
4. Check documentation is rendered correctly
5. Review inputs, outputs, and resources

**Test module consumption:**
```hcl
module "test" {
  source  = "app.terraform.io/<org-name>/<module-name>/<provider>"
  version = "1.0.0"
  
  # Required variables
  environment = "dev"
  owner       = "test-team"
  cost_center = "testing"
  project     = "validation"
}
```

### 10. Module Maintenance

**Updating modules:**
1. Make changes in module directory
2. Update version in git tag
3. Run tests: `terraform test`
4. Commit and push with new tag
5. HCP Terraform auto-publishes new version

**Deprecating modules:**
1. Add deprecation notice to README.md
2. Publish final version with deprecation warning
3. Provide migration path to replacement module

**Module lifecycle:**
- Development → Testing → Publishing → Maintenance → Deprecation

## Tool Selection: MCP Server vs tfctl

**Priority: Always try MCP Server first, use tfctl as fallback**

### Use MCP Server (Primary Tool)
The Terraform MCP server provides high-level, user-friendly tools for common operations:

**Provider & Module Operations:**
- ✅ `search_providers` → `get_provider_details` - Query provider documentation
- ✅ `get_latest_provider_version` - Get latest provider versions
- ✅ `search_modules` → `get_module_details` - Search for module patterns
- ✅ `search_private_modules` → `get_private_module_details` - Private module discovery

**Workspace Operations:**
- ✅ `list_workspaces` - List workspaces with filtering
- ✅ `get_workspace_details` - Get workspace information
- ✅ `create_workspace` - Create new workspaces
- ✅ `update_workspace` - Modify workspace settings

**Run Operations:**
- ✅ `create_run` - Create new runs
- ✅ `get_run_details` - Get run information
- ✅ `get_plan_details` - Get plan information
- ✅ `apply_run` - Apply runs (with user confirmation)

**Variable Operations:**
- ✅ `list_workspace_variables` - List workspace variables
- ✅ `create_workspace_variable` - Create variables
- ✅ `update_workspace_variable` - Update variables

### Use tfctl (Fallback Tool)
Use tfctl when MCP server doesn't provide the needed functionality:

**Advanced Queries:**
- Complex filtering with `--jq` expressions
- Server-side search with `-f` filters
- Pagination control with `--page-size` and `--all`

**Operations Not in MCP:**
- Variable sets management
- Team and team-workspace operations
- Notification configurations
- State version queries
- Configuration version details
- Policy set operations
- Organization settings queries

**Example Decision Flow:**
```
Need to list workspaces?
  → Try: list_workspaces (MCP) ✅
  → If not sufficient, use: tfctl api /organizations/{org}/workspaces

Need to search workspaces by VCS repo?
  → MCP doesn't support this
  → Use: tfctl api /organizations/{org}/workspaces --all --jq 'filter by vcs-repo'

Need to create a run?
  → Try: create_run (MCP) ✅
  → If fails, use: tfctl run create WORKSPACE

Need to query variable sets?
  → MCP doesn't support variable sets
  → Use: tfctl api /organizations/{org}/varsets
```

## MCP Server Integration

Use Terraform MCP server as your primary tool for:
- Provider documentation queries
- Module discovery and details
- Workspace management
- Run creation and monitoring
- Variable management

## tfctl CLI Integration

Use tfctl when MCP server doesn't provide the needed functionality (see tfctl skill for full details):

**Common Operations:**
```bash
# List workspaces in organization
tfctl api /organizations/{organization}/workspaces --jq '.data[] | {id, name: .attributes.name}'

# Get workspace details
tfctl api /organizations/{organization}/workspaces/NAME --jq '.data | {id, name: .attributes.name, terraform_version: .attributes.["terraform-version"]}'

# List variables in workspace
tfctl api /workspaces/{workspace}/vars -p workspace=NAME --jq '.data[] | {key: .attributes.key, category: .attributes.category}'

# Create a run
tfctl run create WORKSPACE

# Check run status
tfctl run status WORKSPACE

# Get organization details
tfctl api /organizations/{organization} --jq '.data | {name: .attributes.name, terraform_version: .attributes.["terraform-version"]}'
```

**Key tfctl Rules:**
- Always use `--jq '<expr>'` for JSON filtering (never pipe to external jq)
- Use `-p workspace=NAME` to resolve workspace names to IDs automatically
- Workspace-specific paths are `/workspaces/{workspace}/...` not `/organizations/{org}/workspaces/{name}/...`
- Never issue DELETE operations - ask user to run the command manually
- Trust the first answer - don't re-query in different formats

## Policy Compliance

Modules MUST pass these Sentinel policies:
- **security-baseline.sentinel** (hard-mandatory): Encryption, tags, network isolation
- **cost-limits.sentinel** (soft-mandatory): Max $100/month delta, $200/month total
- **module-source-restriction.sentinel** (hard-mandatory): No public registry modules

## Common Pitfalls to Avoid

1. ❌ Using inline security blocks instead of separate resources
2. ❌ Missing required tags (Environment, Owner, CostCenter, Project)
3. ❌ Not encrypting storage/compute resources
4. ❌ Using public registry modules (blocked by policy)
5. ❌ Hardcoding values instead of using variables
6. ❌ Not including usage examples
7. ❌ Missing provider version constraints

## Resource Type Coverage

Support these resource types across all clouds:

**Compute:**
- Virtual Machines / Instances
- Container Services (ECS, AKS, GKE, IKS)
- Serverless Functions (Lambda, Azure Functions, Cloud Functions, Code Engine)
- Kubernetes Clusters

**Storage:**
- Object Storage (S3, Blob Storage, Cloud Storage, COS)
- Block Storage (EBS, Managed Disks, Persistent Disks, Block Storage)
- File Storage (EFS, Azure Files, Filestore, File Storage)

**Network:**
- Virtual Networks (VPC, VNet, VPC)
- Load Balancers (ALB/NLB, Load Balancer, Cloud Load Balancing, Load Balancer)
- DNS Services (Route53, DNS, Cloud DNS, DNS Services)
- VPN/Direct Connect

**Database:**
- Relational (RDS, SQL Database, Cloud SQL, Databases for PostgreSQL/MySQL)
- NoSQL (DynamoDB, Cosmos DB, Firestore, Cloudant)
- Cache (ElastiCache, Redis Cache, Memorystore, Databases for Redis)

**Security:**
- Key Management (KMS, Key Vault, Cloud KMS, Key Protect)
- Secrets Management (Secrets Manager, Key Vault, Secret Manager, Secrets Manager)
- Identity & Access (IAM, Azure AD, IAM, IAM)