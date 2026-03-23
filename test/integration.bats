#!/usr/bin/env bats
# Integration tests — boots a real VM and tests the things you'd
# actually need a disposable VM for: sudo, iptables, systemd, Docker
# daemon ops, destructive commands, and network isolation.
#
# Run: bats test/integration.bats
# Or:  make test-integration

TEST_DIR="/tmp/vagrant-skill-integration-test"

setup_file() {
  rm -rf "$TEST_DIR"
  mkdir -p "$TEST_DIR"

  echo '.vagrant/' > "$TEST_DIR/.gitignore"

  # Minimal project — just enough to test syncing
  cat > "$TEST_DIR/Makefile" << 'EOF'
.PHONY: test
test:
	@echo "tests passed"
EOF

  # Vagrantfile with Docker + network tools — the real use case
  cat > "$TEST_DIR/Vagrantfile" << 'VEOF'
VM_CPUS   = Integer(ENV["VM_CPUS"]   || 2)
VM_MEMORY = Integer(ENV["VM_MEMORY"] || 2048)

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.box_check_update = false
  config.vm.hostname = "integration-test"
  config.vm.boot_timeout = 600
  config.ssh.forward_agent = true

  config.vm.synced_folder ".", "/project", type: "rsync",
    rsync__exclude: [".git/", ".vagrant/"]

  config.vm.provider "parallels" do |prl|
    prl.cpus   = VM_CPUS
    prl.memory = VM_MEMORY
    prl.update_guest_tools = true
  end

  config.vm.provider "libvirt" do |lv|
    lv.cpus   = VM_CPUS
    lv.memory = VM_MEMORY
    lv.cpu_mode = "host-passthrough"
    lv.nested = true
  end

  config.vm.provider "virtualbox" do |vb|
    vb.cpus   = VM_CPUS
    vb.memory = VM_MEMORY
    vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
  end

  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq build-essential curl git jq ca-certificates gnupg \
      iptables dnsmasq dnsutils iproute2 net-tools nginx

    if ! command -v docker &>/dev/null; then
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc
      chmod a+r /etc/apt/keyrings/docker.asc
      echo "deb [arch=$(dpkg --print-architecture) \
        signed-by=/etc/apt/keyrings/docker.asc] \
        https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt-get update -qq
      apt-get install -y -qq docker-ce docker-ce-cli containerd.io
    fi
    systemctl enable --now docker
    usermod -aG docker vagrant

    # Stop services that tests will manage
    systemctl stop nginx 2>/dev/null || true
    systemctl stop dnsmasq 2>/dev/null || true
    systemctl disable dnsmasq 2>/dev/null || true

    echo "VM ready"
  SHELL
end
VEOF

  cd "$TEST_DIR"
  vagrant up
}

teardown_file() {
  if [ -d "$TEST_DIR" ]; then
    cd "$TEST_DIR"
    vagrant destroy -f 2>/dev/null || true
    rm -rf "$TEST_DIR"
  fi
}

# ─── Core: VM is up and usable ──────────────────────────────────────────────

@test "VM is running Ubuntu 24.04" {
  cd "$TEST_DIR"
  vagrant ssh -c "grep -q 'Ubuntu 24.04' /etc/os-release" 2>/dev/null
}

@test "project source synced at /project" {
  cd "$TEST_DIR"
  vagrant ssh -c "test -f /project/Makefile" 2>/dev/null
}

@test "rsync propagates host changes into VM" {
  cd "$TEST_DIR"
  echo "sync-marker-$(date +%s)" > "$TEST_DIR/sync-test.txt"
  vagrant rsync 2>/dev/null
  vagrant ssh -c "grep -q sync-marker /project/sync-test.txt" 2>/dev/null
}

# ─── Sudo / root operations ─────────────────────────────────────────────────

@test "vagrant user has passwordless sudo" {
  cd "$TEST_DIR"
  vagrant ssh -c "sudo whoami" 2>/dev/null | grep -q "root"
}

@test "can install packages with sudo" {
  cd "$TEST_DIR"
  vagrant ssh -c "sudo apt-get install -y -qq sqlite3 > /dev/null 2>&1 && sqlite3 --version" 2>/dev/null
}

# ─── Firewall / iptables ────────────────────────────────────────────────────

@test "iptables rules can be added and listed" {
  cd "$TEST_DIR"
  vagrant ssh -c "sudo iptables -A INPUT -p tcp --dport 9999 -j DROP" 2>/dev/null
  result=$(vagrant ssh -c "sudo iptables -L INPUT -n" 2>/dev/null)
  echo "$result" | grep -q "9999"
}

@test "iptables rules can be flushed without consequence" {
  cd "$TEST_DIR"
  vagrant ssh -c "sudo iptables -F" 2>/dev/null
  result=$(vagrant ssh -c "sudo iptables -L -n" 2>/dev/null)
  echo "$result" | grep -q "Chain INPUT (policy ACCEPT)"
}

# ─── systemd services ───────────────────────────────────────────────────────

@test "can start and stop systemd services" {
  cd "$TEST_DIR"
  vagrant ssh -c "sudo systemctl start nginx && systemctl is-active nginx" 2>/dev/null | grep -q "active"
  vagrant ssh -c "sudo systemctl stop nginx && systemctl is-active nginx 2>&1 || true" 2>/dev/null | grep -q "inactive"
}

@test "can enable and disable systemd services" {
  cd "$TEST_DIR"
  vagrant ssh -c "sudo systemctl enable nginx 2>/dev/null && systemctl is-enabled nginx" 2>/dev/null | grep -q "enabled"
  vagrant ssh -c "sudo systemctl disable nginx 2>/dev/null && systemctl is-enabled nginx 2>&1 || true" 2>/dev/null | grep -q "disabled"
}

# ─── Docker daemon operations ───────────────────────────────────────────────

@test "Docker daemon is running" {
  cd "$TEST_DIR"
  vagrant ssh -c "docker info > /dev/null 2>&1" 2>/dev/null
}

@test "Docker can build and run images" {
  cd "$TEST_DIR"
  vagrant ssh -c "docker run --rm hello-world" 2>/dev/null | grep -q "Hello from Docker"
}

@test "Docker can bind privileged ports" {
  cd "$TEST_DIR"
  vagrant ssh -c "docker run -d --name test-nginx -p 80:80 nginx:alpine > /dev/null 2>&1 && sleep 2 && curl -sf http://localhost > /dev/null && docker rm -f test-nginx > /dev/null 2>&1" 2>/dev/null
}

# ─── Network isolation ──────────────────────────────────────────────────────

@test "VM has its own network stack" {
  cd "$TEST_DIR"
  result=$(vagrant ssh -c "ip addr show" 2>/dev/null)
  echo "$result" | grep -q "eth0"
}

@test "DNS resolution works inside VM" {
  cd "$TEST_DIR"
  vagrant ssh -c "dig +short example.com | head -1" 2>/dev/null | grep -qE '^[0-9]'
}

# ─── Destructive operations (the whole point) ───────────────────────────────

@test "can write to system directories" {
  cd "$TEST_DIR"
  vagrant ssh -c "sudo touch /etc/test-marker && test -f /etc/test-marker && sudo rm /etc/test-marker" 2>/dev/null
}

@test "can rm -rf system directories without host impact" {
  cd "$TEST_DIR"
  vagrant ssh -c "sudo rm -rf /var/log/nginx && test ! -d /var/log/nginx" 2>/dev/null
}

@test "host is unaffected by VM destruction" {
  # This test just proves the host is still fine after all the chaos above
  test -f "$TEST_DIR/Vagrantfile"
  test -f "$TEST_DIR/Makefile"
}

# ─── Idempotent reprovisioning ──────────────────────────────────────────────

@test "reprovisioning succeeds after destructive tests" {
  cd "$TEST_DIR"
  vagrant provision 2>&1 | grep -q "VM ready"
}
