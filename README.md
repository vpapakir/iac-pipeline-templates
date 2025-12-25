# iac-pipeline-templates

Centralized CI/CD pipeline templates for cloud-agnostic infrastructure automation following the atom-molecule-template architecture pattern.

## Overview

This repository provides reusable pipeline templates that implement standardized plan-test-release workflows across multiple CI/CD platforms. These templates are designed to be consumed by infrastructure modules (atoms and molecules) to ensure consistent automation practices organization-wide.

## Architecture Philosophy

### Template-Based Reusability
- **Single Source of Truth**: All pipeline logic centralized in one repository
- **Consistent Workflows**: Identical plan-test-release patterns across all infrastructure modules
- **Parameterized Configuration**: Module-specific settings without duplicating pipeline logic
- **Version Control**: Template updates propagate to all consuming modules

### Multi-Platform Support
- **Azure DevOps** - Primary implementation with full feature set
- **GitHub Actions** - Mirror of Azure DevOps functionality
- **AWS CodePipeline** - CloudFormation-based pipeline templates
- **Oracle Cloud DevOps** - OCI DevOps build specifications

## Supported Workflows

### Plan-Test-Release Pipeline
1. **Commit Check** - Platform filtering based on commit message prefixes
2. **Plan** - Terraform module consumption testing using example configurations
3. **Test** - Security scanning (Checkov) and code quality validation
4. **Create PR** - Automated pull request creation for release workflows
5. **Release** - Intelligent semantic versioning and module publishing

### Intelligent Features
- **Commit Message Routing**: `[ado]`, `[gh]`, `[aws]`, `[oci]` prefixes control platform execution
- **Conditional Stages**: PR creation only with `[release]` flag on feature branches
- **Semantic Versioning**: Reviewer-controlled version bumps via approval messages
- **Multi-Cloud Testing**: Validates modules across Azure, AWS, Civo, and OCI

## Repository Structure

```
iac-pipeline-templates/
├── azure-devops/              # Azure DevOps pipeline templates
│   ├── stages/                # Stage-level templates
│   │   ├── commit-check.yml   # Platform filtering logic
│   │   ├── plan.yml           # Module consumption testing
│   │   ├── test.yml           # Security scanning & linting
│   │   ├── create-pr.yml      # Automated PR creation
│   │   └── release.yml        # Intelligent versioning & publishing
│   └── jobs/                  # Job-level templates
│       ├── commit-check.yml   # Commit message parsing
│       ├── terraform-plan.yml # Terraform plan execution
│       ├── terraform-test.yml # Security & quality checks
│       ├── create-pr.yml      # GitHub PR creation
│       └── terraform-release.yml # Version management & tagging
├── github-actions/            # GitHub Actions workflow templates (future)
├── aws-codepipeline/          # AWS CodePipeline templates (future)
├── oracle-devops/             # Oracle Cloud DevOps templates (future)
└── README.md
```

## Usage

### Azure DevOps Integration

#### 1. Reference Templates Repository
```yaml
# .azure/pipeline.yml
resources:
  repositories:
  - repository: templates
    type: github
    name: vpapakir/iac-pipeline-templates
    ref: main
```

#### 2. Consume Stage Templates
```yaml
stages:
- template: azure-devops/stages/plan.yml@templates
  parameters:
    condition: eq(variables.shouldRun, true)
    terraformVersion: '1.6.0'
    examplePaths: 
      - 'examples/my-module-example'

- template: azure-devops/stages/test.yml@templates
  parameters:
    condition: eq(variables.shouldRun, true)
    terraformVersion: '1.6.0'
    modulePaths:
      - 'iac/terraform/aws'
      - 'iac/terraform/azure'
```

#### 3. Configure Module-Specific Variables
```yaml
variables:
  terraformVersion: '1.6.0'
  shouldRun: $[or(contains(variables['Build.SourceVersionMessage'], '[ado]'), not(or(contains(variables['Build.SourceVersionMessage'], '[gh]'), contains(variables['Build.SourceVersionMessage'], '[aws]'))))]
  shouldCreatePR: $[and(contains(variables['Build.SourceVersionMessage'], '[release]'), ne(variables['Build.SourceBranch'], 'refs/heads/main'))]
  shouldRelease: $[or(eq(variables['Build.SourceBranch'], 'refs/heads/main'), eq(variables['Build.SourceBranch'], 'refs/heads/master'))]
```

### Complete Example

```yaml
# Infrastructure module: .azure/pipeline.yml
trigger:
  branches:
    include: [main, master]
  paths:
    exclude: [README.md, .github/*, .aws/*]

pool:
  vmImage: 'ubuntu-latest'

variables:
  terraformVersion: '1.6.0'
  shouldRun: $[or(contains(variables['Build.SourceVersionMessage'], '[ado]'), not(or(contains(variables['Build.SourceVersionMessage'], '[gh]'), contains(variables['Build.SourceVersionMessage'], '[aws]'))))]
  shouldCreatePR: $[and(contains(variables['Build.SourceVersionMessage'], '[release]'), ne(variables['Build.SourceBranch'], 'refs/heads/main'))]
  shouldRelease: $[or(eq(variables['Build.SourceBranch'], 'refs/heads/main'), eq(variables['Build.SourceBranch'], 'refs/heads/master'))]

resources:
  repositories:
  - repository: templates
    type: github
    name: vpapakir/iac-pipeline-templates
    ref: main

stages:
- template: azure-devops/stages/commit-check.yml@templates
  parameters:
    condition: true
    platformPrefix: '[ado]'
    excludePrefixes: ['[gh]', '[aws]']

- template: azure-devops/stages/plan.yml@templates
  parameters:
    condition: eq(variables.shouldRun, true)
    terraformVersion: $(terraformVersion)
    examplePaths: ['examples/compute-example']

- template: azure-devops/stages/test.yml@templates
  parameters:
    condition: eq(variables.shouldRun, true)
    terraformVersion: $(terraformVersion)
    modulePaths: ['iac/terraform/azure', 'iac/terraform/aws']

- template: azure-devops/stages/create-pr.yml@templates
  parameters:
    condition: and(succeeded(), eq(variables.shouldCreatePR, true))

- template: azure-devops/stages/release.yml@templates
  parameters:
    condition: and(succeeded(), eq(variables.shouldRelease, true))
```

## Template Parameters

### Stage Templates

#### commit-check.yml
- `condition` (boolean) - Whether to run the stage
- `platformPrefix` (string) - Platform identifier (e.g., '[ado]')
- `excludePrefixes` (array) - Other platform prefixes to exclude

#### plan.yml
- `condition` (boolean) - Whether to run the stage
- `terraformVersion` (string) - Terraform version to install
- `examplePaths` (array) - Paths to example configurations for testing

#### test.yml
- `condition` (boolean) - Whether to run the stage
- `terraformVersion` (string) - Terraform version to install
- `modulePaths` (array) - Paths to Terraform modules for scanning

#### create-pr.yml
- `condition` (boolean) - Whether to run the stage

#### release.yml
- `condition` (boolean) - Whether to run the stage

## Required Variable Groups

### Azure DevOps
- **terraform** Variable Group:
  - `apiKey` - Terraform Cloud API token
- **shared** Variable Group:
  - `ARM_CLIENT_ID` - Azure Service Principal ID
  - `ARM_CLIENT_SECRET` - Azure Service Principal Secret
  - `ARM_SUBSCRIPTION_ID` - Azure Subscription ID
  - `ARM_TENANT_ID` - Azure Tenant ID
  - `GITHUB_TOKEN` - GitHub Personal Access Token

## Commit Message Conventions

Control pipeline execution using commit message prefixes:

```bash
# Platform-specific execution
git commit -m "[ado] feat: add new feature"     # Azure DevOps only
git commit -m "[gh] fix: bug fix"               # GitHub Actions only
git commit -m "[aws] chore: update config"      # AWS CodePipeline only
git commit -m "[oci] docs: update docs"         # Oracle Cloud DevOps only

# Release workflow
git commit -m "[ado][release] feat: ready for release"  # Creates PR
git commit -m "fix: bug fix"                            # Default (Azure DevOps)
```

## Semantic Versioning

Intelligent version management based on PR approval messages:

### Version Bump Logic
- **APPROVED MAJOR** → Major version bump (1.0.0 → 2.0.0)
- **APPROVED MINOR** → Minor version bump (1.0.0 → 1.1.0)
- **APPROVED PATCH** or default → Patch version bump (1.0.0 → 1.0.1)

### Workflow Example
1. Developer: `git commit -m "[ado][release] feat: new cloud provider"`
2. Pipeline creates PR automatically
3. Reviewer approves with: "APPROVED MINOR - adds OCI support"
4. PR merge triggers release pipeline
5. Pipeline creates version 1.1.0 and publishes to Terraform Cloud

## Development Workflow

### For Infrastructure Module Developers
1. **Setup**: Reference this template repository in your pipeline
2. **Configure**: Set module-specific paths and parameters
3. **Develop**: Work on feature branches with standard commits
4. **Release**: Add `[release]` flag when ready for publication
5. **Review**: Team reviews auto-created PR and controls version bump

### For Template Maintainers
1. **Update**: Modify templates in this repository
2. **Version**: Tag releases for consuming modules to reference
3. **Test**: Validate changes across multiple infrastructure modules
4. **Document**: Update README and parameter documentation

## Benefits

### For Development Teams
- **Consistency**: Same workflow across all infrastructure modules
- **Efficiency**: No pipeline code duplication or maintenance
- **Quality**: Built-in security scanning and code quality checks
- **Automation**: Intelligent versioning and release management

### For Platform Teams
- **Governance**: Centralized control over CI/CD standards
- **Scalability**: Easy to onboard new infrastructure modules
- **Maintenance**: Single point of updates for all pipelines
- **Compliance**: Consistent security and quality gates

## Future Enhancements

- **GitHub Actions Templates**: Complete GitHub Actions workflow templates
- **AWS CodePipeline Templates**: CloudFormation-based pipeline templates
- **Oracle Cloud DevOps Templates**: OCI DevOps build specifications
- **Policy Integration**: Policy-as-code validation stages
- **Cost Analysis**: Automated cost estimation and optimization
- **Multi-Environment**: Environment-specific deployment templates

## Contributing

1. **Fork** this repository
2. **Create** feature branch for template updates
3. **Test** changes with existing infrastructure modules
4. **Document** parameter changes and new features
5. **Submit** pull request with detailed description

## License

See [LICENSE](LICENSE) file for details.