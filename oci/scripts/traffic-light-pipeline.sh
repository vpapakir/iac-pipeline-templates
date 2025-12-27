#!/bin/bash
set -e

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --ci-tool)
      CI_TOOL="$2"
      shift 2
      ;;
    --default-cloud-provider)
      DEFAULT_CLOUD_PROVIDER="$2"
      shift 2
      ;;
    --terraform-cloud-token)
      TF_CLOUD_TOKEN="$2"
      shift 2
      ;;
    --github-token)
      GITHUB_TOKEN="$2"
      shift 2
      ;;
    --commit-sha)
      COMMIT_SHA="$2"
      shift 2
      ;;
    --branch-ref)
      BRANCH_REF="$2"
      shift 2
      ;;
    --repo-name)
      REPO_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Get commit message
COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null | head -1 | tr -d '\n\r' || echo "")
echo "Commit message: '$COMMIT_MSG'"

# Check if this pipeline should run
if [[ "$COMMIT_MSG" != *"[$CI_TOOL]"* ]]; then
  echo "❌ Skipping - not $CI_TOOL job"
  exit 0
fi

echo "✅ $CI_TOOL should handle this"

# Install dependencies
echo "Installing Terraform..."
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
mv terraform /usr/local/bin/
terraform --version

echo "Installing Checkov..."
yum install -y python3 python3-pip git
pip3 install checkov

# Configure Terraform Cloud
mkdir -p ~/.terraform.d
echo "credentials \"app.terraform.io\" { token = \"$TF_CLOUD_TOKEN\" }" > ~/.terraform.d/credentials.tfrc.json

# Determine cloud provider
if [[ "$COMMIT_MSG" == *"[oci]"* ]]; then
  CLOUD_PROVIDER="oci"
elif [[ "$COMMIT_MSG" == *"[aws]"* ]]; then
  CLOUD_PROVIDER="aws"
elif [[ "$COMMIT_MSG" == *"[azure]"* ]]; then
  CLOUD_PROVIDER="azure"
elif [[ "$COMMIT_MSG" == *"[civo]"* ]]; then
  CLOUD_PROVIDER="civo"
else
  CLOUD_PROVIDER="$DEFAULT_CLOUD_PROVIDER"
fi

echo "Target cloud provider: $CLOUD_PROVIDER"

# BUILD: Validate and test
echo "→ Running validation for $CLOUD_PROVIDER..."

# Test example if exists
if [ -d "examples/${CLOUD_PROVIDER}-example" ]; then
  cd "examples/${CLOUD_PROVIDER}-example"
  terraform init && terraform plan && terraform validate
  cd ../..
fi

# Test module
if [ -d "iac/terraform/${CLOUD_PROVIDER}" ]; then
  cd "iac/terraform/${CLOUD_PROVIDER}"
  terraform init && terraform fmt -check && terraform validate
  checkov -d . --framework terraform
  cd ../../..
fi

# RELEASE: Create PR if release action
if [[ "$COMMIT_MSG" == *"[release]"* ]] && [[ "$BRANCH_REF" != "main" ]]; then
  echo "→ Creating release PR..."
  
  # Create PR using GitHub API
  curl -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/$REPO_NAME/pulls \
    -d "{
      \"title\": \"Release: ${CLOUD_PROVIDER} module updates\",
      \"body\": \"Automated release PR\\n\\nApprove with: [APPROVED] [PATCH] [$CI_TOOL]\",
      \"head\": \"$BRANCH_REF\",
      \"base\": \"main\"
    }"
  
  echo "✅ Release PR created"
  
# PUBLISH: Release module if on main branch
elif [[ "$BRANCH_REF" == "main" ]]; then
  echo "→ Main branch detected"
  
  # Get PR merge commit message for approval
  MERGE_MSG=$(git log -1 --pretty=%B 2>/dev/null || echo "")
  echo "Merge message: $MERGE_MSG"
  
  # Check if this tool should publish
  if [[ "$MERGE_MSG" != *"[$CI_TOOL]"* ]]; then
    echo "❌ Skipping publish - not approved for $CI_TOOL"
    exit 0
  fi
  
  echo "✅ Publishing module..."
  
  # Configure git
  git config --global user.email "pipeline@oracle.com"
  git config --global user.name "$CI_TOOL"
  
  # Determine version bump
  if [[ "$MERGE_MSG" == *"[MAJOR]"* ]]; then
    BUMP_TYPE="major"
  elif [[ "$MERGE_MSG" == *"[MINOR]"* ]]; then
    BUMP_TYPE="minor"
  else
    BUMP_TYPE="patch"
  fi
  
  # Get current version and bump
  git fetch --tags
  LATEST_TAG=$(git tag -l "v*" | sort -V | tail -n1)
  
  if [ -z "$LATEST_TAG" ]; then
    NEW_VERSION="0.0.1"
  else
    CURRENT_VERSION=${LATEST_TAG#v}
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
    
    case $BUMP_TYPE in
      major) NEW_VERSION="$((MAJOR + 1)).0.0" ;;
      minor) NEW_VERSION="$MAJOR.$((MINOR + 1)).0" ;;
      patch) NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))" ;;
    esac
  fi
  
  # Create and push tag
  git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"
  git remote set-url origin https://$GITHUB_TOKEN@github.com/$REPO_NAME.git
  git push origin "v$NEW_VERSION"
  
  echo "🚀 Published version: v$NEW_VERSION"
fi