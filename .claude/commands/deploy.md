---
description: Deploy infrastructure using Terraform
allowed-tools: Read, Bash(terraform *:*), Bash(git status:*), Bash(git branch:*), Glob
---

# Deploy

Deploy infrastructure using Terraform.

## Step 1: Pre-Deploy Checks

1. Verify working tree is clean: `git status`
2. Verify current branch (warn if not main)
3. Run `terraform validate`
4. Check if a deployment runbook exists: `ls docs/runbooks/deploy-*.md`

## Step 2: Follow Runbook or Execute

If a deployment runbook exists in `docs/runbooks/`, follow its steps.

Otherwise:
```bash
terraform plan
# Wait for user confirmation
terraform apply
```

## Step 3: Verify

After deployment:
- Check Terraform outputs: `terraform output`
- Verify instance status if applicable

## Step 4: Summary

Display what was deployed and verification results.
