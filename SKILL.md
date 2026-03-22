---
name: vagrant
description: >-
  Disposable VMs for safe testing — full sudo, Docker, Go, nested KVM, destroy
  and recreate. Use when you need a sandbox to build, test, or break things
  without affecting the host. Use when the user says "spin up a VM", "test in
  isolation", "run with sudo", "try something dangerous", "set up a dev
  environment", "I need Docker", "test firewall rules", "clean environment",
  or needs root access, network testing, or safe experimentation.
license: Apache-2.0
compatibility: >-
  Requires vagrant binary and at least one provider: Parallels (Mac Apple
  Silicon), libvirt (Linux), or VirtualBox (cross-platform). Designed for
  terminal-based AI agents and interactive developer use.
allowed-tools: "Bash(vagrant:*) Bash(make:*) Read Write"
metadata:
  author: daax-dev
  version: "0.1.0"
  category: infrastructure
  tags: [vm, sandbox, testing, docker, devops, isolation, kvm]
  openclaw:
    requires:
      bins:
        - vagrant
      anyBins:
        - VBoxManage
        - virsh
        - prlctl
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Execution Instructions

This skill provides a **disposable VM sandbox** for safe development and testing. All privileged operations (sudo, iptables, Docker, systemd, KVM) happen inside the VM — the host is never modified.

**You (the agent) should NEVER need host-level sudo.** Instead, use this Vagrant workflow to get a fully provisioned, disposable VM where you have unrestricted root access.

### Prerequisites

Before using this workflow, verify a provider is available:

```bash
# Check Vagrant is installed
command -v vagrant

# Check for a provider (any one is sufficient)
command -v prlctl        # Parallels (Mac Apple Silicon — recommended)
vagrant plugin list | grep libvirt  # libvirt (Linux — nested KVM)
command -v VBoxManage    # VirtualBox (fallback)
```

See [references/platform-setup.md](references/platform-setup.md) for detailed provider installation.

---

## Core Workflow

### Step 1: Create a Vagrantfile in the User's Project

**IMPORTANT:** The Vagrantfile in this skill directory is a reference example only. You must create a Vagrantfile **in the user's working directory** so they can reuse it. The `.vagrant/` directory (VM state) must be gitignored.

If the user's project does not already have a `Vagrantfile`, create one:

```ruby
# -*- mode: ruby -*-
# Vagrantfile — disposable dev/test VM (created by vagrant skill)

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.hostname = "dev"

  # ─── Sync project source into the VM ──────────────────────────────────────
  config.vm.synced_folder ".", "/project", type: "rsync",
    rsync__exclude: [".git/", "node_modules/", "vendor/", ".vagrant/"]

  # ─── Provider: Parallels (Mac Apple Silicon) ──────────────────────────────
  config.vm.provider "parallels" do |prl|
    prl.cpus   = Integer(ENV["VM_CPUS"]   || 4)
    prl.memory = Integer(ENV["VM_MEMORY"] || 4096)
    prl.update_guest_tools = true
  end

  # ─── Provider: libvirt (Linux — nested KVM) ───────────────────────────────
  config.vm.provider "libvirt" do |lv|
    lv.cpus   = Integer(ENV["VM_CPUS"]   || 4)
    lv.memory = Integer(ENV["VM_MEMORY"] || 4096)
    lv.cpu_mode = "host-passthrough"
    lv.nested = true
  end

  # ─── Provider: VirtualBox ─────────────────────────────────────────────────
  config.vm.provider "virtualbox" do |vb|
    vb.cpus   = Integer(ENV["VM_CPUS"]   || 4)
    vb.memory = Integer(ENV["VM_MEMORY"] || 4096)
    vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
  end

  # ─── Provision ────────────────────────────────────────────────────────────
  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq build-essential curl git jq docker.io
    systemctl enable --now docker
    usermod -aG docker vagrant
    echo "VM ready — project synced at /project"
  SHELL
end
```

Adapt the provisioning inline script to the user's needs (e.g., add Go, Python, Node, or other tooling). The example above is minimal — add what the project requires.

Then **add `.vagrant/` to the user's `.gitignore`** if not already present:

```bash
grep -qxF '.vagrant/' .gitignore 2>/dev/null || echo '.vagrant/' >> .gitignore
```

The Vagrantfile itself **should be committed** — it's reusable project config.

### Step 2: Start the VM

```bash
vagrant up
```

This boots the VM with the user's project synced at `/project` inside the VM.

### Step 3: Run Commands Inside the VM

**All commands use `vagrant ssh -c` from the host.** No interactive SSH needed.

```bash
# Run any command with sudo
vagrant ssh -c "sudo apt-get install -y some-package"

# Build the project
vagrant ssh -c "cd /project && make build"
vagrant ssh -c "cd /project && go test ./..."

# Docker operations
vagrant ssh -c "docker build -t myimage ."
vagrant ssh -c "docker run --rm myimage"

# Network/firewall testing
vagrant ssh -c "sudo iptables -L -n"
```

### Step 4: Iterate on Code Changes

When you modify source on the host:

```bash
vagrant rsync                                    # sync changes to VM
vagrant ssh -c "cd /project && make build"       # rebuild
vagrant ssh -c "cd /project && make test"        # test
```

### Step 5: Tear Down

```bash
vagrant destroy -f    # destroys VM completely, clean slate
```

---

## Testing Patterns

### Pattern: Build-Test-Fix Loop

```bash
vagrant rsync && vagrant ssh -c "cd /project && make build"
vagrant ssh -c "cd /project && make test"
# If tests fail, fix code on host, repeat
```

### Pattern: Docker-in-VM

```bash
vagrant ssh -c "cd /project && docker build -t test ."
vagrant ssh -c "docker run --rm test"
```

### Pattern: Network/Firewall Testing

```bash
vagrant ssh -c "sudo iptables -A FORWARD -s 172.16.0.0/24 -j DROP"
vagrant ssh -c "sudo iptables -L -n -v"
```

### Pattern: Full Reprovision (Nuclear Option)

```bash
vagrant destroy -f && vagrant up
```

---

## Configuration

Environment variables to customize the VM (set before `vagrant up`):

| Variable | Default | Purpose |
|----------|---------|---------|
| `VM_CPUS` | 4 | Number of vCPUs |
| `VM_MEMORY` | 4096 | RAM in MB |

Example:
```bash
VM_CPUS=8 VM_MEMORY=8192 vagrant up
```

See [references/vm-contents.md](references/vm-contents.md) for full details on VM filesystem layout and installed software.

## Safety Guarantees

- **No host sudo required** — all privileged operations are inside the VM
- **Fully disposable** — `vagrant destroy -f` removes everything
- **Idempotent provisioning** — `vagrant provision` is safe to re-run
- **Isolated networking** — VM has its own network stack
- **Source is rsynced** — VM gets a copy; your host repo is never modified by the VM
- **No persistent state** — destroying the VM removes all data
- **Vagrantfile is committed** — reusable across sessions; `.vagrant/` is gitignored

## Examples

### Example 1: Test a Go project in a clean environment

User says: "I need to test this Go project in a clean environment"

Actions:
1. Check if `Vagrantfile` exists in project root — if not, create one with Go provisioning
2. Add `.vagrant/` to `.gitignore`
3. `vagrant up`
4. `vagrant ssh -c "cd /project && go test ./..."`
5. `vagrant destroy -f`

Result: Tests run in isolated Ubuntu 24.04 VM, no host contamination. Vagrantfile stays for next time.

### Example 2: Safe firewall rule testing

User says: "I need to test some iptables rules without breaking my network"

Actions:
1. Create Vagrantfile with network tools provisioned
2. `vagrant up`
3. `vagrant ssh -c "sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT"`
4. `vagrant ssh -c "sudo iptables -L -n -v"`
5. `vagrant destroy -f`

Result: Firewall rules tested safely inside VM, host network untouched.

### Example 3: Docker build and test

User says: "Build and test this Docker image"

Actions:
1. Create Vagrantfile with Docker provisioned (docker.io or Docker CE)
2. `vagrant up`
3. `vagrant ssh -c "cd /project && docker build -t myapp ."`
4. `vagrant ssh -c "docker run --rm myapp test"`
5. `vagrant destroy -f`

Result: Docker image built and tested inside VM with its own Docker daemon.

## Troubleshooting

### VM Won't Boot

**Error:** `vagrant up` hangs or times out
**Cause:** Provider not installed or configured correctly
**Solution:**
1. Check provider is installed: `vagrant plugin list`
2. Debug boot: `vagrant up --debug 2>&1 | tail -50`
3. Try explicit provider: `vagrant up --provider=virtualbox`

### Source Not Synced

**Error:** `/project` directory is empty or missing inside VM
**Cause:** rsync failed or synced_folder misconfigured
**Solution:**
1. Re-sync: `vagrant rsync`
2. Check Vagrantfile has `synced_folder ".", "/project", type: "rsync"`

### Provider Mismatch

**Error:** `vagrant up` uses wrong provider
**Cause:** Multiple providers installed, Vagrant auto-selects
**Solution:**
1. Check what's running: `vagrant status`
2. Force provider: `vagrant up --provider=parallels`

### KVM Not Available Inside VM

**Error:** `/dev/kvm` missing inside the VM
**Cause:** Host doesn't support nested virtualization or provider not configured
**Solution:**
1. Ensure host has KVM: `test -e /dev/kvm` on host
2. Use libvirt provider with `cpu_mode = "host-passthrough"`
3. Mac: nested KVM is not available — use a Linux host for KVM workloads
