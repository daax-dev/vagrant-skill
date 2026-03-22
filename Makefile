.PHONY: lint test test-integration test-all up destroy clean

# ─── Lint ────────────────────────────────────────────────────────────────────
lint:
	@echo "▶ shellcheck"
	shellcheck scripts/setup.sh scripts/verify.sh
	@echo "▶ ruby syntax (Vagrantfile)"
	ruby -c Vagrantfile
	@echo "▶ All lint passed"

# ─── Unit Tests (bats-core) ─────────────────────────────────────────────────
test:
	@command -v bats >/dev/null 2>&1 || { echo "Install bats-core: brew install bats-core (Mac) or apt-get install bats (Linux)"; exit 1; }
	bats test/

# ─── Integration Tests (requires Vagrant + provider) ────────────────────────
test-integration:
	@echo "▶ Starting VM..."
	vagrant up
	@echo "▶ Running verification inside VM..."
	vagrant ssh -c "sudo /vagrant-scripts/scripts/verify.sh"
	@echo "▶ Integration tests passed"
	vagrant destroy -f

# ─── All Tests ───────────────────────────────────────────────────────────────
test-all: lint test test-integration

# ─── Dev shortcuts ───────────────────────────────────────────────────────────
up:
	vagrant up

destroy:
	vagrant destroy -f

clean: destroy
	@echo "Clean"
