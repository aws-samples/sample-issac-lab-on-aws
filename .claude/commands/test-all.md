---
description: Execute the full test suite and report results
allowed-tools: Read, Bash(bash tests/*:*), Bash(terraform validate:*), Bash(terraform fmt -check:*), Glob
---

# Test All

Execute the full test suite for this project.

## Step 1: Terraform Validation

```bash
terraform validate
terraform fmt -check
```

## Step 2: Run Harness Tests

```bash
bash tests/run-all.sh
```

## Step 3: Workshop Build Check

```bash
cd workshop && npx honkit build 2>&1 | tail -5
```

## Step 4: Report

Present:
- Terraform validation result
- Harness test results (total, passed, failed)
- Workshop build result
- Suggest fixes for failing tests if the cause is apparent
