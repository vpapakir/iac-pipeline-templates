# iac-pipeline-templates

Centralized CI/CD pipeline templates implementing the **traffic light system** for cloud-agnostic infrastructure automation across multiple CI/CD platforms..

## Overview

This repository provides reusable pipeline templates that implement standardized plan-test-release workflows with intelligent platform routing. The **traffic light system** ensures only the intended CI tool runs for each commit, preventing pipeline conflicts and resource waste.

## Traffic Light System

### Commit Message Convention

All commits must follow this format to control which CI/CD platform executes:

```
[repo] [cloud] [ci-tool] [action] <description>
```

**Components:**

- `[repo]`: Repository platform - `[github]` (future: `[gitlab]`, `[bitbucket]`)
- `[cloud]`: Target cloud provider - `[azure]`, `[aws]`, `[civo]`, `[oci]`
- `[ci-tool]`: CI/CD platform - `[ado]`, `[gh_actions]`, `[aws_pipeline]`, `[oci_pipeline]`
- `[action]`: Pipeline action - `[build]`, `[release]`

**Examples:**

```bash
# Azure DevOps builds Azure module
git commit -m "[github] [azure] [ado] [build] fix: update VM sizes"

# GitHub Actions builds AWS module  
git commit -m "[github] [aws] [gh_actions] [build] feat: add instance types"

# AWS CodePipeline creates release PR
git commit -m "[github] [aws] [aws_pipeline] [release] feat: ready for release"
```

### Pipeline Execution Matrix

| Commit Message | Azure DevOps | GitHub Actions | AWS CodePipeline | OCI DevOps |
|---|---|---|---|---|
| `[github] [azure] [ado] [build]` | ✅ Run | ❌ Skip | ❌ Skip | ❌ Skip |
| `[github] [aws] [gh_actions] [release]` | ❌ Skip | ✅ Run | ❌ Skip | ❌ Skip |
| `[github] [civo] [aws_pipeline] [build]` | ❌ Skip | ❌ Skip | ✅ Run | ❌ Skip |
| `[github] [oci] [oci_pipeline] [release]` | ❌ Skip | ❌ Skip | ❌ Skip | ✅ Run |

## Repository Structure

```
iac-pipeline-templates/
├── .github/workflows/
│   ├── traffic-light-pipeline.yml    # GitHub Actions reusable workflow
│   ├── sanity-check.yml              # Weekly code quality checks
│   └── reusable-sanity-check.yml     # Reusable sanity check workflow
├── azure/stages/
│   └── traffic-light-pipeline.yml    # Azure DevOps template
├── aws/scripts/
│   └── traffic-light-pipeline.sh     # AWS CodeBuild script
├── oci/scripts/
│   └── traffic-light-pipeline.sh     # OCI DevOps script
└── README.md
```

## Template Features

### Traffic Light Pipeline

Standardized plan-test-release workflows with intelligent platform routing.

### Automated Code Quality

Weekly code quality checks with YAML, Markdown, and Shell script linting.

### Azure DevOps Template

**File:** `azure/stages/traffic-light-pipeline.yml`

**Parameters:**

- `ciTool` - CI tool identifier (e.g., "ado")
- `defaultCloudProvider` - Default cloud when not specified
- `terraformCloudToken` - Terraform Cloud API token
- `githubToken` - GitHub token for PR creation
- `azureCredentials` - Azure authentication object

**Usage:**

```yaml
# .azure/pipeline.yml
resources:
  repositories:
  - repository: templates
    type: github
    name: vpapakir/iac-pipeline-templates
    ref: refs/heads/main
    endpoint: github

stages:
- template: azure/stages/traffic-light-pipeline.yml@templates
  parameters:
    ciTool: 'ado'
    defaultCloudProvider: 'azure'
    terraformCloudToken: $(apiKey)
    githubToken: $(GITHUB_TOKEN)
    azureCredentials:
      clientId: $(ARM_CLIENT_ID)
      clientSecret: $(ARM_CLIENT_SECRET)
      subscriptionId: $(ARM_SUBSCRIPTION_ID)
      tenantId: $(ARM_TENANT_ID)
```

### GitHub Actions Workflow

**File:** `.github/workflows/traffic-light-pipeline.yml`

**Inputs:**

- `ci-tool` - CI tool identifier (e.g., "gh_actions")
- `default-cloud-provider` - Default cloud provider

**Secrets:**

- `terraform-cloud-token` - Terraform Cloud API token
- `github-token` - GitHub token (auto-provided)

**Usage:**

```yaml
# .github/workflows/pipeline.yml
name: Infrastructure Pipeline

on:
  push:
    branches: ['*']
  pull_request:
    branches: [main]

jobs:
  traffic-light-pipeline:
    uses: vpapakir/iac-pipeline-templates/.github/workflows/traffic-light-pipeline.yml@main
    with:
      ci-tool: 'gh_actions'
      default-cloud-provider: 'aws'
    secrets:
      terraform-cloud-token: ${{ secrets.TF_CLOUD_TOKEN }}
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

### AWS CodeBuild Script

**File:** `aws/scripts/traffic-light-pipeline.sh`

**Parameters:**

- `--ci-tool` - CI tool identifier
- `--default-cloud-provider` - Default cloud provider
- `--terraform-cloud-token` - Terraform Cloud token
- `--github-token` - GitHub token
- `--commit-sha` - Commit SHA for GitHub API
- `--branch-ref` - Branch reference
- `--repo-name` - Repository name

**Usage:**

```yaml
# buildspec.yml
version: 0.2

phases:
  build:
    commands:
      - |
        curl -H "Authorization: token $GITHUB_TOKEN" \
          -H "Accept: application/vnd.github.v3.raw" \
          -o pipeline.sh \
          https://api.github.com/repos/vpapakir/iac-pipeline-templates/contents/aws/scripts/traffic-light-pipeline.sh
        
        chmod +x pipeline.sh
        
        ./pipeline.sh \
          --ci-tool "aws_pipeline" \
          --default-cloud-provider "aws" \
          --terraform-cloud-token "$TF_CLOUD_TOKEN" \
          --github-token "$GITHUB_TOKEN" \
          --commit-sha "$CODEBUILD_RESOLVED_SOURCE_VERSION" \
          --branch-ref "$CODEBUILD_WEBHOOK_HEAD_REF" \
          --repo-name "vpapakir/iac-molecule-compute"
```

### Sanity Check Workflow

**File:** `.github/workflows/reusable-sanity-check.yml`

**Inputs:**

- `terraform-version` - Terraform version (default: '1.6.0')
- `create-pr` - Whether to create PR with fixes (default: true)

**Features:**

- Terraform formatting (`terraform fmt`)
- Static analysis (TFLint)
- Security scanning (Checkov, TFSec)
- Automated PR creation with fixes

**Usage:**

```yaml
# .github/workflows/sanity-check.yml
name: Weekly Sanity Check

on:
  schedule:
    - cron: '0 3 * * 1'  # Weekly Monday 3 AM
  workflow_dispatch:

jobs:
  sanity-check:
    uses: vpapakir/iac-pipeline-templates/.github/workflows/reusable-sanity-check.yml@main
    with:
      terraform-version: '1.6.0'
      create-pr: true
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

**File:** `oci/scripts/traffic-light-pipeline.sh`

**Parameters:** Same as AWS script

**Usage:**

```yaml
# .oci/build_spec.yaml
version: 0.1
component: build

steps:
  - type: Command
    name: "Execute Traffic Light Pipeline"
    command: |
      curl -H "Authorization: token $GITHUB_TOKEN" \
        -o pipeline.sh \
        https://api.github.com/repos/vpapakir/iac-pipeline-templates/contents/oci/scripts/traffic-light-pipeline.sh
      
      chmod +x pipeline.sh
      
      ./pipeline.sh \
        --ci-tool "oci_pipeline" \
        --default-cloud-provider "oci" \
        --terraform-cloud-token "$TF_CLOUD_TOKEN" \
        --github-token "$GITHUB_TOKEN" \
        --commit-sha "$OCI_BUILD_COMMIT_HASH" \
        --branch-ref "$OCI_BUILD_GIT_BRANCH" \
        --repo-name "vpapakir/iac-molecule-compute"
```

## Pipeline Stages

### 1. Commit Check

- Parses commit message for CI tool identifier
- Skips execution if wrong CI tool
- Determines target cloud provider
- Sets variables for subsequent stages

### 2. Build & Validate

- Installs Terraform and dependencies
- Configures Terraform Cloud authentication
- Tests example configurations (terraform plan)
- Validates module code (terraform validate, fmt)
- Runs security scanning (Checkov)

### 3. Create PR (Conditional)

- **Trigger:** `[release]` in commit message + not on main branch
- Creates automated pull request to main branch
- Includes approval template with version control

### 4. Publish (Conditional)

- **Trigger:** Pipeline runs on main/master branch
- Parses PR approval message for version bump
- Creates semantic version tag
- Publishes module to registry

## Semantic Versioning

### PR Approval Format

```
[APPROVED] [VERSION_BUMP] [ci-tool] <description>
```

**Examples:**

```bash
# Patch version bump via Azure DevOps
"[APPROVED] [PATCH] [ado] looks good to go"

# Minor version bump via GitHub Actions  
"[APPROVED] [MINOR] [gh_actions] new features added"

# Major version bump via AWS CodePipeline
"[APPROVED] [MAJOR] [aws_pipeline] breaking changes"
```

### Version Logic

- `[MAJOR]` → Major version bump (1.0.0 → 2.0.0)
- `[MINOR]` → Minor version bump (1.0.0 → 1.1.0)
- `[PATCH]` or default → Patch version bump (1.0.0 → 1.0.1)

## Required Environment Variables

### Azure DevOps Variable Groups

**`terraform` Variable Group:**

- `apiKey` - Terraform Cloud API token

**`shared` Variable Group:**

- `ARM_CLIENT_ID` - Azure Service Principal ID
- `ARM_CLIENT_SECRET` - Azure Service Principal Secret
- `ARM_SUBSCRIPTION_ID` - Azure Subscription ID
- `ARM_TENANT_ID` - Azure Tenant ID
- `GITHUB_TOKEN` - GitHub Personal Access Token

### GitHub Actions Secrets

- `TF_CLOUD_TOKEN` - Terraform Cloud API token
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

### AWS CodeBuild Environment Variables

- `TF_CLOUD_TOKEN` - Terraform Cloud API token (Plaintext)
- `GITHUB_TOKEN` - GitHub Personal Access Token

### OCI DevOps Parameters

- `TF_CLOUD_TOKEN` - Terraform Cloud API token
- `GITHUB_TOKEN` - GitHub Personal Access Token

## Development Workflow

### 1. Development Testing

```bash
git commit -m "[github] [aws] [gh_actions] [build] fix: update security groups"
```

- Only GitHub Actions runs
- Validates AWS module
- No PR creation

### 2. Release Creation

```bash
git commit -m "[github] [aws] [gh_actions] [release] feat: new compute features"
```

- GitHub Actions runs validation
- Creates automated PR to main branch
- Waits for team review

### 3. Release Approval

```bash
# In GitHub PR comment/approval
"[APPROVED] [MINOR] [gh_actions] new features look good"
```

- PR merge triggers GitHub Actions on main
- Creates version 1.1.0 tag
- Publishes module to registry

## Benefits

✅ **No Pipeline Conflicts** - Only one CI tool runs per commit  
✅ **Resource Efficiency** - Eliminates redundant pipeline executions  
✅ **Clear Intent** - Commit message explicitly states execution plan  
✅ **Flexible Publishing** - Choose which CI tool publishes final module  
✅ **Multi-Cloud Support** - Test different providers in different CI environments  
✅ **Centralized Maintenance** - Update templates to update all projects  
✅ **Consistent Behavior** - Same logic across all CI platforms  
✅ **Automated Code Quality** - Weekly sanity checks with auto-fix PRs  

## Contributing

When contributing to templates:

1. **Test Changes** - Validate across multiple infrastructure projects
2. **Version Updates** - Tag releases for consuming projects to reference
3. **Documentation** - Update this README for any parameter changes
4. **Backward Compatibility** - Maintain existing parameter interfaces

## License

See [LICENSE](LICENSE) file for details.
