#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# Build Custom Web Portal AMI
# 
# Purpose: Build Amazon Linux 2 AMI with Nginx pre-installed
#          for faster ASG EC2 startup
#
# Usage:
#   bash packer/build.sh
#   OR
#   bash packer/build.sh --region us-west-2
# ══════════════════════════════════════════════════════════════════

set -euo pipefail

# ──────────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_REGION="${1:-us-east-1}"
PACKER_FILE="${SCRIPT_DIR}/web-portal.pkr.hcl"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ──────────────────────────────────────────────────────────────────
# Pre-flight checks
# ──────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[CHECK] Validating environment...${NC}"

# Check Packer is installed
if ! command -v packer &>/dev/null; then
  echo -e "${RED}[ERROR] Packer not found. Install from: https://www.packer.io/downloads${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Packer found: $(packer version)${NC}"

# Check AWS CLI is installed
if ! command -v aws &>/dev/null; then
  echo -e "${RED}[ERROR] AWS CLI not found. Install from: https://aws.amazon.com/cli/${NC}"
  exit 1
fi
echo -e "${GREEN}✓ AWS CLI found${NC}"

# Check AWS credentials
if ! aws sts get-caller-identity --region "$AWS_REGION" &>/dev/null; then
  echo -e "${RED}[ERROR] AWS credentials not configured. Run: aws configure${NC}"
  exit 1
fi
echo -e "${GREEN}✓ AWS credentials valid${NC}"

# Check Packer file exists
if [[ ! -f "$PACKER_FILE" ]]; then
  echo -e "${RED}[ERROR] Packer file not found: $PACKER_FILE${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Packer file found${NC}"

echo ""
echo -e "${YELLOW}[BUILD] Starting Packer build...${NC}"
echo "Region: $AWS_REGION"
echo "Packer file: $PACKER_FILE"
echo ""

# ──────────────────────────────────────────────────────────────────
# Format and Validate Packer configuration
# ──────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[FORMAT] Formatting Packer configuration...${NC}"
packer fmt "$PACKER_FILE"
echo -e "${GREEN}✓ Format complete${NC}"

echo ""
echo -e "${YELLOW}[VALIDATE] Validating Packer configuration...${NC}"
packer validate \
  -var="aws_region=$AWS_REGION" \
  "$PACKER_FILE"
echo -e "${GREEN}✓ Validation complete${NC}"

# ──────────────────────────────────────────────────────────────────
# Build AMI
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[BUILD] Building custom AMI...${NC}"
echo "This will take 5-10 minutes..."
echo ""

packer build \
  -var="aws_region=$AWS_REGION" \
  "$PACKER_FILE"

# ──────────────────────────────────────────────────────────────────
# Success message
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ AMI Build Successful!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Get the AMI ID from above output (look for 'id: ami-xxxxxxxxx')"
echo "2. Update modules/ec2/variables.tf with the AMI ID"
echo "3. Update your terraform.tfvars:"
echo "   web_portal_ami_id = \"ami-xxxxxxxxx\""
echo ""
echo -e "${YELLOW}Example:${NC}"
echo "   aws ec2 describe-images --region $AWS_REGION --owners self --query 'Images[0].ImageId'"
echo ""
