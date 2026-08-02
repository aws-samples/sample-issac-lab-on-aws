#!/bin/bash
# --- Manifest validation ---
assert_json_valid "settings.json is valid JSON" ".claude/settings.json"

# --- File existence ---
assert_file_exists "Root CLAUDE.md" "CLAUDE.md"
assert_file_exists "docs/architecture.md" "docs/architecture.md"
assert_file_exists "Workshop CLAUDE.md" "workshop/CLAUDE.md"

# --- Script validation ---
assert_file_executable "setup.sh is executable" "scripts/setup.sh"
assert_bash_syntax "setup.sh valid bash" "scripts/setup.sh"
assert_file_executable "install-hooks.sh is executable" "scripts/install-hooks.sh"
assert_bash_syntax "install-hooks.sh valid bash" "scripts/install-hooks.sh"

# --- Command frontmatter ---
for cmd in review test-all deploy; do
    CMD_CONTENT=$(cat ".claude/commands/$cmd.md")
    assert_contains "Command $cmd: has frontmatter" "$CMD_CONTENT" "description:"
    assert_contains "Command $cmd: has allowed-tools" "$CMD_CONTENT" "allowed-tools:"
done

# --- CLAUDE.md content ---
SECTIONS=("Overview" "Architecture" "Key Gotchas" "Commands")
for section in "${SECTIONS[@]}"; do
    grep -qi "$section" CLAUDE.md && pass "CLAUDE.md: has $section" || fail "CLAUDE.md: has $section" "not found"
done

# --- Terraform files ---
assert_file_exists "main.tf exists" "main.tf"
assert_file_exists "variables.tf exists" "variables.tf"
assert_file_exists "outputs.tf exists" "outputs.tf"
