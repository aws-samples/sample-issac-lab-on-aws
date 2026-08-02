---
description: Run code review on current changes with confidence-based filtering
allowed-tools: Read, Glob, Grep, Bash(git diff:*), Bash(git log:*), Bash(terraform validate:*)
---

# Code Review

Review the current code changes using confidence-based scoring.

## Step 1: Get Changes

Determine the scope of review:

- If $ARGUMENTS specifies files, review those files
- Otherwise, review unstaged changes: `git diff`
- If no unstaged changes, review staged changes: `git diff --cached`

## Step 2: Review

For each changed file, apply the code-review skill criteria:
- Project guidelines compliance (from CLAUDE.md)
- Bug detection (logic errors, security, Terraform misconfiguration)
- Code quality (duplication, complexity)

## Step 3: Score and Filter

Rate each issue 0-100. Only report issues with confidence >= 75.

## Step 4: Output

Present findings in structured format with file paths, line numbers, and fix suggestions.
If no high-confidence issues, confirm code meets standards.

## Error Recovery

### If no changes found (Step 1)
- Check if changes are committed: `git log -1 --oneline`
- Suggest specifying files directly: `/review path/to/file`

### If CLAUDE.md is missing or empty (Step 2)
- Suggest running `/init-project` to generate CLAUDE.md
