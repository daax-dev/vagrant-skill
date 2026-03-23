#!/usr/bin/env bats
# Integration tests — boots a real VM, provisions it, verifies end-to-end.
# Requires: vagrant + a provider (parallels, libvirt, or virtualbox)
#
# Run: bats test/integration.bats
# Or:  make test-integration

TEST_DIR="/tmp/vagrant-skill-integration-test"

setup_file() {
  # Create test project
  rm -rf "$TEST_DIR"
  mkdir -p "$TEST_DIR"

  echo 'module test-project' > "$TEST_DIR/go.mod"
  echo '.vagrant/' > "$TEST_DIR/.gitignore"
  cat > "$TEST_DIR/main.go" << 'GOEOF'
package main

import "fmt"

func main() { fmt.Println("hello from vagrant-skill") }
GOEOF

  # Write the Vagrantfile the skill would produce for a Go project
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
    apt-get install -y -qq build-essential curl git jq ca-certificates gnupg

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

    GO_VERSION="1.24.3"
    if [ ! -x /usr/local/go/bin/go ]; then
      curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" \
        | tar -C /usr/local -xz
      echo 'export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"' > /etc/profile.d/go.sh
      echo 'export GOPATH="$HOME/go"' >> /etc/profile.d/go.sh
    fi

    echo "VM ready"
  SHELL
end
VEOF

  # Boot the VM
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

@test "VM is running" {
  cd "$TEST_DIR"
  vagrant status | grep -q "running"
}

@test "Ubuntu 24.04 is the guest OS" {
  cd "$TEST_DIR"
  result=$(vagrant ssh -c "cat /etc/os-release" 2>/dev/null)
  echo "$result" | grep -q "Ubuntu 24.04"
}

@test "project source is synced at /project" {
  cd "$TEST_DIR"
  vagrant ssh -c "test -f /project/go.mod" 2>/dev/null
  vagrant ssh -c "test -f /project/main.go" 2>/dev/null
}

@test "Docker is installed and daemon is running" {
  cd "$TEST_DIR"
  vagrant ssh -c "docker --version" 2>/dev/null | grep -q "Docker version"
  vagrant ssh -c "docker info > /dev/null 2>&1" 2>/dev/null
}

@test "Docker can run containers" {
  cd "$TEST_DIR"
  result=$(vagrant ssh -c "docker run --rm hello-world" 2>/dev/null)
  echo "$result" | grep -q "Hello from Docker"
}

@test "Go is installed" {
  cd "$TEST_DIR"
  result=$(vagrant ssh -c "export PATH=/usr/local/go/bin:\$PATH && go version" 2>/dev/null)
  echo "$result" | grep -q "go1.24"
}

@test "Go project builds and runs" {
  cd "$TEST_DIR"
  result=$(vagrant ssh -c "export PATH=/usr/local/go/bin:\$PATH && cd /project && go build -o /tmp/test-app . && /tmp/test-app" 2>/dev/null)
  echo "$result" | grep -q "hello from vagrant-skill"
}

@test "vagrant user has sudo" {
  cd "$TEST_DIR"
  vagrant ssh -c "sudo whoami" 2>/dev/null | grep -q "root"
}

@test "rsync updates reach the VM" {
  cd "$TEST_DIR"
  echo "rsync-test-marker" > "$TEST_DIR/rsync-check.txt"
  vagrant rsync 2>/dev/null
  vagrant ssh -c "cat /project/rsync-check.txt" 2>/dev/null | grep -q "rsync-test-marker"
}

@test ".vagrant/ is not synced into VM" {
  cd "$TEST_DIR"
  vagrant ssh -c "test ! -d /project/.vagrant" 2>/dev/null
}

@test "VM can be reprovisioned idempotently" {
  cd "$TEST_DIR"
  vagrant provision 2>&1 | grep -q "VM ready"
}
