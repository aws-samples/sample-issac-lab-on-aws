#!/bin/bash
# Scan staged files for secrets before commit.

SECRETS_FOUND=0

PATTERNS=(
    'AKIA[0-9A-Z]{16}'
    'sk-ant-[A-Za-z0-9-]{90,}'
    'ghp_[A-Za-z0-9]{36}'
    'xoxb-[0-9]+-[A-Za-z0-9]+'
    'sk_live_[A-Za-z0-9]{24,}'
    'AIza[A-Za-z0-9_-]{35}'
    'password\s*[:=]\s*["\x27][^"\x27]{8,}'
    'api[_-]?key\s*[:=]\s*["\x27][^"\x27]{8,}'
)

SKIP_PATTERNS=('.env.example' 'secret-scan.sh' '*.md' 'package-lock.json' 'terraform.tfvars.example' 'tests/fixtures/*')

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)
[ -z "$STAGED_FILES" ] && exit 0

for file in $STAGED_FILES; do
    skip=false
    for pattern in "${SKIP_PATTERNS[@]}"; do
        [[ "$file" == $pattern ]] && skip=true && break
    done
    $skip && continue
    [ ! -f "$file" ] && continue

    for regex in "${PATTERNS[@]}"; do
        if grep -qP "$regex" "$file" 2>/dev/null; then
            echo "[secret-scan] Potential secret found in $file (pattern: ${regex:0:30}...)"
            SECRETS_FOUND=1
        fi
    done
done

if [ "$SECRETS_FOUND" -eq 1 ]; then
    echo "[secret-scan] BLOCKED: Potential secrets detected in staged files."
    exit 1
fi
