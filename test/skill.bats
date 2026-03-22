#!/usr/bin/env bats
# Tests for SKILL.md format validation — ensures compatibility with
# both Claude Code and OpenClaw skill formats.

SKILL_FILE="$BATS_TEST_DIRNAME/../SKILL.md"

@test "SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "SKILL.md has valid frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  # Find the closing ---
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "SKILL.md has name field" {
  grep -q "^name:" "$SKILL_FILE"
}

@test "SKILL.md has description field" {
  grep -q "^description:" "$SKILL_FILE"
}

@test "SKILL.md has version field (OpenClaw requirement)" {
  grep -q "^version:" "$SKILL_FILE"
}

@test "SKILL.md has openclaw metadata (bins requirement)" {
  grep -q "bins:" "$SKILL_FILE"
  grep -q "vagrant" "$SKILL_FILE"
}

@test "SKILL.md contains execution instructions" {
  grep -q "## Execution Instructions" "$SKILL_FILE"
}

@test "SKILL.md contains core workflow" {
  grep -q "## Core Workflow" "$SKILL_FILE"
}

@test "SKILL.md contains safety guarantees" {
  grep -q "## Safety Guarantees" "$SKILL_FILE"
}

@test ".claude/skills/vagrant/SKILL.md exists (Claude Code path)" {
  [ -L "$BATS_TEST_DIRNAME/../.claude/skills/vagrant/SKILL.md" ] || \
  [ -f "$BATS_TEST_DIRNAME/../.claude/skills/vagrant/SKILL.md" ]
}
