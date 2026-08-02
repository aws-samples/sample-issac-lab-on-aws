#!/bin/bash
# Project setup script for new developers.
# Usage: bash scripts/setup.sh

set -e

echo "=== Project Setup ==="

# Check prerequisites
command -v git >/dev/null 2>&1 || { echo "ERROR: git is required"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "ERROR: terraform is required"; exit 1; }

# Setup environment
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "IMPORTANT: Edit .env with your actual values"
fi

# Check terraform.tfvars
if [ ! -f "terraform.tfvars" ] && [ -f "terraform.tfvars.example" ]; then
    echo "Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "IMPORTANT: Edit terraform.tfvars with your NGC API key and settings"
fi

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Validate
echo "Validating Terraform..."
terraform validate

# Setup Claude hooks
if [ -f ".claude/hooks/check-doc-sync.sh" ]; then
    chmod +x .claude/hooks/*.sh
    echo "Claude hooks configured"
fi

# Install Git hooks
if [ -d ".git" ] && [ -f "scripts/install-hooks.sh" ]; then
    bash scripts/install-hooks.sh
fi

# Workshop dependencies (optional)
if [ -f "workshop/package.json" ]; then
    echo "Installing workshop dependencies..."
    cd workshop && npm install && cd ..
fi

echo "=== Setup Complete ==="
echo "Next steps:"
echo "  1. Edit terraform.tfvars with your configuration"
echo "  2. Read CLAUDE.md for project conventions"
echo "  3. Read docs/onboarding.md for development workflow"
echo "  4. Run: terraform plan"
