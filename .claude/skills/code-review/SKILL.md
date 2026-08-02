# Code Review Skill

Review changed code with confidence-based scoring to filter false positives.

## Review Scope

By default, review unstaged changes from `git diff`. The user may specify different files or scope.

## Review Criteria

### Project Guidelines Compliance
- Terraform HCL conventions and `terraform fmt` compliance
- Shell script safety patterns (set -e, quoting)
- Workshop markdown consistency and link validity
- Naming conventions from CLAUDE.md

### Bug Detection
- Terraform resource misconfiguration
- Shell script logic errors and unquoted variables
- Security vulnerabilities (exposed secrets, overly permissive IAM)
- user_data.sh templatefile variable escaping (`$$` vs `$`)

### Code Quality
- Code duplication and unnecessary complexity
- Missing critical error handling
- HonKit chapter cross-reference integrity

## Confidence Scoring

Rate each issue 0-100:
- **0-24**: Likely false positive. Do not report.
- **25-49**: Might be real but possibly a nitpick. Do not report.
- **50-74**: Real issue but minor. Report only if critical.
- **75-89**: Verified real issue, important. Report with fix suggestion.
- **90-100**: Confirmed critical issue. Must report.

**Only report issues with confidence >= 75.**

## Output Format

For each issue:
### [CRITICAL|IMPORTANT] <issue title> (confidence: XX)
**File:** `path/to/file.ext:line`
**Issue:** Clear description of the problem
**Guideline:** Reference to CLAUDE.md rule or security standard
**Fix:** Concrete code suggestion

If no high-confidence issues found, confirm code meets standards with brief summary.
