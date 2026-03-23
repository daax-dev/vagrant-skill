.PHONY: lint test test-unit test-integration test-all up destroy clean

# ─── Lint ────────────────────────────────────────────────────────────────────
lint:
	@echo "▶ shellcheck"
	shellcheck scripts/setup.sh scripts/verify.sh
	@echo "▶ ruby syntax (Vagrantfile)"
	ruby -c Vagrantfile
	@echo "▶ All lint passed"

# ─── Unit Tests (structure/format only, no VM) ──────────────────────────────
test-unit:
	@command -v bats >/dev/null 2>&1 || { echo "Install bats-core: brew install bats-core (Mac) or apt-get install bats (Linux)"; exit 1; }
	bats test/scripts.bats test/skill.bats test/vagrantfile.bats

# ─── Integration Tests (boots a real VM, requires Vagrant + provider) ───────
test-integration:
	@command -v bats >/dev/null 2>&1 || { echo "Install bats-core: brew install bats-core (Mac) or apt-get install bats (Linux)"; exit 1; }
	@command -v vagrant >/dev/null 2>&1 || { echo "Install vagrant: brew install --cask vagrant"; exit 1; }
	bats test/integration.bats

# ─── All Unit Tests (default) ───────────────────────────────────────────────
test: test-unit

# ─── All Tests ───────────────────────────────────────────────────────────────
test-all: lint test-unit test-integration

# ─── Dev shortcuts ───────────────────────────────────────────────────────────
up:
	vagrant up

destroy:
	vagrant destroy -f

clean: destroy
	@echo "Clean"
