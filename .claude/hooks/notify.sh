#!/bin/bash
# Send notifications via webhook on Claude Code events.

WEBHOOK_URL="${CLAUDE_NOTIFY_WEBHOOK:-}"
[ -z "$WEBHOOK_URL" ] && exit 0

EVENT="${1:-unknown}"
MESSAGE="${2:-Claude Code event occurred}"

PAYLOAD=$(cat <<EOF
{
  "text": "[$EVENT] $MESSAGE",
  "project": "$(basename $(pwd))",
  "branch": "$(git branch --show-current 2>/dev/null || echo 'unknown')",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)

curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" > /dev/null 2>&1 &
