#!/usr/bin/env bats
# Tests for SKILL.md format validation — ensures compatibility with
# the Agent Skills specification (agentskills.io), Claude Code, and OpenClaw.

SKILL_FILE="$BATS_TEST_DIRNAME/../SKILL.md"

# ─── File existence ──────────────────────────────────────────────────────────

@test "SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "SKILL.md has valid frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  # Find the closing ---
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

# ─── Required fields (Agent Skills spec) ──────────────────────────────────────

@test "SKILL.md has name field" {
  grep -q "^name:" "$SKILL_FILE"
}

@test "SKILL.md name is kebab-case (no spaces, no uppercase)" {
  name=$(grep "^name:" "$SKILL_FILE" | head -1 | sed 's/^name: *//')
  echo "$name" | grep -qE '^[a-z][a-z0-9-]*[a-z0-9]$'
}

@test "SKILL.md has description field" {
  grep -q "^description:" "$SKILL_FILE"
}

@test "SKILL.md description includes trigger phrases" {
  # Extract full description (may span multiple lines with >- syntax)
  grep -q "Use when" "$SKILL_FILE"
}

@test "SKILL.md has no XML tags in frontmatter" {
  # Extract frontmatter (between --- delimiters), exclude YAML >- syntax
  frontmatter=$(awk '/^---$/{n++; next} n==1' "$SKILL_FILE")
  ! echo "$frontmatter" | grep -qE '<[a-zA-Z/]'
}

# ─── Optional fields (Agent Skills spec) ──────────────────────────────────────

@test "SKILL.md has license field" {
  grep -q "^license:" "$SKILL_FILE"
}

@test "SKILL.md has compatibility field" {
  grep -q "^compatibility:" "$SKILL_FILE"
}

@test "SKILL.md has allowed-tools field" {
  grep -q "^allowed-tools:" "$SKILL_FILE"
}

@test "SKILL.md has metadata with author" {
  grep -q "author:" "$SKILL_FILE"
}

@test "SKILL.md has metadata with version" {
  grep -q "version:" "$SKILL_FILE"
}

# ─── OpenClaw compatibility ──────────────────────────────────────────────────

@test "SKILL.md has openclaw metadata with bins requirement" {
  grep -q "bins:" "$SKILL_FILE"
  grep -q "vagrant" "$SKILL_FILE"
}

@test "SKILL.md has openclaw anyBins with provider binaries" {
  grep -q "anyBins:" "$SKILL_FILE"
  grep -q "VBoxManage" "$SKILL_FILE"
  grep -q "virsh" "$SKILL_FILE"
  grep -q "prlctl" "$SKILL_FILE"
}

# ─── Content sections ────────────────────────────────────────────────────────

@test "SKILL.md contains execution instructions" {
  grep -q "## Execution Instructions" "$SKILL_FILE"
}

@test "SKILL.md contains core workflow" {
  grep -q "## Core Workflow" "$SKILL_FILE"
}

@test "SKILL.md contains safety guarantees" {
  grep -q "## Safety Guarantees" "$SKILL_FILE"
}

@test "SKILL.md contains examples section" {
  grep -q "## Examples" "$SKILL_FILE"
}

@test "SKILL.md contains troubleshooting section" {
  grep -q "## Troubleshooting" "$SKILL_FILE"
}

@test "SKILL.md references files in references/ directory" {
  grep -q "references/" "$SKILL_FILE"
}

# ─── Workflow design ─────────────────────────────────────────────────────────

@test "SKILL.md instructs agent to create Vagrantfile in user's directory" {
  grep -q "Create a Vagrantfile" "$SKILL_FILE" || \
  grep -q "create a Vagrantfile" "$SKILL_FILE" || \
  grep -q "Create.*Vagrantfile.*user" "$SKILL_FILE"
}

@test "SKILL.md instructs agent to gitignore .vagrant/" {
  grep -q '\.vagrant/' "$SKILL_FILE"
  grep -q 'gitignore\|\.gitignore' "$SKILL_FILE"
}

@test "SKILL.md includes example Vagrantfile with synced_folder" {
  grep -q 'synced_folder' "$SKILL_FILE"
}

@test "SKILL.md states skill Vagrantfile is example/reference only" {
  grep -qi 'reference example\|example only' "$SKILL_FILE"
}

@test "SKILL.md says Vagrantfile should be committed" {
  grep -qi 'should be committed\|Vagrantfile.*committed' "$SKILL_FILE"
}

# ─── Progressive disclosure ──────────────────────────────────────────────────

@test "SKILL.md is under 500 lines" {
  line_count=$(wc -l < "$SKILL_FILE")
  [ "$line_count" -lt 500 ]
}

@test "references/ directory exists with reference files" {
  [ -d "$BATS_TEST_DIRNAME/../references" ]
  [ -f "$BATS_TEST_DIRNAME/../references/platform-setup.md" ]
  [ -f "$BATS_TEST_DIRNAME/../references/vm-contents.md" ]
}

# ─── Claude Code integration ─────────────────────────────────────────────────

@test ".claude/skills/vagrant/SKILL.md exists (Claude Code path)" {
  [ -L "$BATS_TEST_DIRNAME/../.claude/skills/vagrant/SKILL.md" ] || \
  [ -f "$BATS_TEST_DIRNAME/../.claude/skills/vagrant/SKILL.md" ]
}

@test "SKILL.md contains user input section for Claude Code arguments" {
  grep -q '\$ARGUMENTS' "$SKILL_FILE"
}
