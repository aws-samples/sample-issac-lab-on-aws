#!/bin/bash
# True positive tests — patterns that MUST match
# NOTE: test tokens are assembled from parts at runtime so the full token
# never appears verbatim in source (keeps secret scanners quiet).
AWS_KEY_PREFIX="AKIA"
AWS_KEY_BODY="IOSFODNN7EXAMPLE" # AWS docs example key (not a real credential)
assert_grep_match "TP: AWS Access Key ID" 'AKIA[0-9A-Z]{16}' "${AWS_KEY_PREFIX}${AWS_KEY_BODY}"

SLACK_PREFIX="xoxb-"
SLACK_BODY="123456789012-1234567890123-abcdef"
assert_grep_match "TP: Slack Bot Token" 'xoxb-[0-9]+-[A-Za-z0-9]+' "${SLACK_PREFIX}${SLACK_BODY}"

# False positive tests — patterns that must NOT match
assert_grep_no_match "FP: Normal base64" 'AKIA[0-9A-Z]{16}' "dGhpcyBpcyBhIHRlc3Q="
assert_grep_no_match "FP: Empty password" 'password\s*[:=]\s*["\x27][^"\x27]{8,}' 'password = ""'
