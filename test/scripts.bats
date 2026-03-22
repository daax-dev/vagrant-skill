#!/usr/bin/env bats
# Tests for provisioning scripts — validates structure, idempotency markers,
# and absence of project-specific tooling.

SETUP="$BATS_TEST_DIRNAME/../scripts/setup.sh"
VERIFY="$BATS_TEST_DIRNAME/../scripts/verify.sh"

# ─── setup.sh ────────────────────────────────────────────────────────────────

@test "setup.sh exists and is executable-ready" {
  [ -f "$SETUP" ]
  head -1 "$SETUP" | grep -q "#!/usr/bin/env bash"
}

@test "setup.sh uses set -euo pipefail" {
  grep -q "set -euo pipefail" "$SETUP"
}

@test "setup.sh installs Docker" {
  grep -q "install_docker" "$SETUP"
}

@test "setup.sh installs Go" {
  grep -q "install_go" "$SETUP"
}

@test "setup.sh installs mage" {
  grep -q "install_mage" "$SETUP"
}

@test "setup.sh installs system deps" {
  grep -q "install_system_deps" "$SETUP"
}

@test "setup.sh does NOT reference nanofuse" {
  ! grep -qi "nanofuse" "$SETUP"
}

@test "setup.sh does NOT reference firecracker" {
  ! grep -qi "firecracker" "$SETUP"
}

@test "setup.sh does NOT build any project-specific binaries" {
  ! grep -q "build_nanofuse\|build_base_image\|register_base_image\|setup_nanofuse_service" "$SETUP"
}

@test "setup.sh supports GO_VERSION env var" {
  grep -q 'GO_VERSION' "$SETUP"
}

@test "setup.sh supports arm64 architecture" {
  grep -q "arm64\|aarch64" "$SETUP"
}

# ─── verify.sh ───────────────────────────────────────────────────────────────

@test "verify.sh exists and is executable-ready" {
  [ -f "$VERIFY" ]
  head -1 "$VERIFY" | grep -q "#!/usr/bin/env bash"
}

@test "verify.sh uses set -euo pipefail" {
  grep -q "set -euo pipefail" "$VERIFY"
}

@test "verify.sh checks Docker" {
  grep -q "Docker" "$VERIFY"
}

@test "verify.sh checks Go" {
  grep -q "Go" "$VERIFY"
}

@test "verify.sh checks network tools" {
  grep -q "iptables" "$VERIFY"
}

@test "verify.sh does NOT reference nanofuse" {
  ! grep -qi "nanofuse" "$VERIFY"
}

@test "verify.sh does NOT reference firecracker" {
  ! grep -qi "firecracker" "$VERIFY"
}

@test "verify.sh exits non-zero on failure" {
  grep -q 'exit 1' "$VERIFY"
}

@test "verify.sh reports pass/fail/skip counts" {
  grep -q 'PASS:' "$VERIFY"
  grep -q 'FAIL:' "$VERIFY"
  grep -q 'SKIP:' "$VERIFY"
}
