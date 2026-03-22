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
allowed-tools: "Bash(vagrant:*) Bash(make:*) Read"
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

### Why This Exists

AI agents and developers need a safe place to:
- Run commands with full sudo without risking the host
- Test firewall rules, network configs, systemd services
- Build and test with Docker, Go, mage
- Use nested KVM for microVM or hypervisor testing
- Break things and start fresh in seconds

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

### Step 1: Provision the VM

```bash
cd vagrant-skill

# Basic — no project sync
vagrant up

# With a project synced into the VM at /project
PROJECT_SRC=/path/to/your/project vagrant up
```

This gives you a VM with:
- Ubuntu 24.04 with full sudo
- Go 1.24.3 + mage build system
- Docker (daemon running)
- Network tools (iptables, dnsmasq, iproute2, dig)
- KVM tools (if nested KVM available on host)

### Step 2: Run Commands Inside the VM

**All commands use `vagrant ssh -c` from the host.** No interactive SSH needed.

```bash
# Run any command with sudo
vagrant ssh -c "sudo apt-get install -y some-package"

# Build a project
vagrant ssh -c "cd /project && make build"
vagrant ssh -c "cd /project && go test ./..."

# Docker operations
vagrant ssh -c "docker build -t myimage ."
vagrant ssh -c "docker run --rm myimage"

# Network/firewall testing
vagrant ssh -c "sudo iptables -L -n"
vagrant ssh -c "sudo systemctl start dnsmasq"

# Run the verification suite
vagrant ssh -c "sudo /vagrant-scripts/scripts/verify.sh"
```

### Step 3: Iterate on Code Changes

When you modify source on the host:

```bash
vagrant rsync                                    # sync changes to VM
vagrant ssh -c "cd /project && make build"       # rebuild
vagrant ssh -c "cd /project && make test"        # test
```

This is fast (~10s for rsync + rebuild) vs. full reprovision.

### Step 4: Tear Down

```bash
vagrant destroy -f    # destroys VM completely, clean slate
```

---

## Testing Patterns

### Pattern: Build-Test-Fix Loop

```bash
# 1. Make code changes on host
# 2. Sync and rebuild
vagrant rsync && vagrant ssh -c "cd /project && make build"
# 3. Run tests
vagrant ssh -c "cd /project && make test"
# 4. If tests fail, read output, fix code, repeat from step 1
```

### Pattern: Docker-in-VM

```bash
vagrant ssh -c "cd /project && docker build -t test ."
vagrant ssh -c "docker run --rm test"
```

### Pattern: Network/Firewall Testing

```bash
# Apply firewall rules
vagrant ssh -c "sudo iptables -A FORWARD -s 172.16.0.0/24 -j DROP"
vagrant ssh -c "sudo iptables -L -n -v"

# DNS filtering
vagrant ssh -c "sudo systemctl start dnsmasq"
vagrant ssh -c "dig example.com @127.0.0.1"
```

### Pattern: Full Reprovision (Nuclear Option)

When things are broken beyond repair:
```bash
vagrant destroy -f && vagrant up    # fresh VM from scratch
```

---

## Configuration

Environment variables to customize the VM:

| Variable | Default | Purpose |
|----------|---------|---------|
| `PROJECT_SRC` | auto-detect | Host directory to sync into VM at `/project` |
| `VM_CPUS` | 4 | Number of vCPUs |
| `VM_MEMORY` | 4096 | RAM in MB |
| `VM_NAME` | vagrant-skill-dev | VM hostname |
| `GO_VERSION` | 1.24.3 | Go version to install |

Example:
```bash
PROJECT_SRC=~/myapp VM_CPUS=8 VM_MEMORY=8192 vagrant up
```

See [references/vm-contents.md](references/vm-contents.md) for full details on VM filesystem layout and installed software.

## Safety Guarantees

- **No host sudo required** — all privileged operations are inside the VM
- **Fully disposable** — `vagrant destroy -f` removes everything
- **Idempotent provisioning** — `vagrant provision` is safe to re-run
- **Isolated networking** — VM has its own network stack
- **Source is rsynced** — VM gets a copy; your host repo is never modified by the VM
- **No persistent state** — destroying the VM removes all data

## Examples

### Example 1: Test a Go project in a clean environment

User says: "I need to test this Go project in a clean environment"

Actions:
1. `PROJECT_SRC=~/myproject vagrant up`
2. `vagrant ssh -c "cd /project && go test ./..."`
3. `vagrant destroy -f`

Result: Tests run in isolated Ubuntu 24.04 VM, no host contamination.

### Example 2: Safe firewall rule testing

User says: "I need to test some iptables rules without breaking my network"

Actions:
1. `vagrant up`
2. `vagrant ssh -c "sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT"`
3. `vagrant ssh -c "sudo iptables -L -n -v"`
4. `vagrant destroy -f`

Result: Firewall rules tested safely inside VM, host network untouched.

### Example 3: Docker build and test

User says: "Build and test this Docker image"

Actions:
1. `PROJECT_SRC=~/myproject vagrant up`
2. `vagrant ssh -c "cd /project && docker build -t myapp ."`
3. `vagrant ssh -c "docker run --rm myapp test"`
4. `vagrant destroy -f`

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
**Cause:** `PROJECT_SRC` not set or rsync failed
**Solution:**
1. Set explicitly: `PROJECT_SRC=~/myproject vagrant up`
2. Re-sync without reprovision: `vagrant rsync`

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
2. Use libvirt provider with `cpu_mode = "host-passthrough"` (automatic in this Vagrantfile)
3. VirtualBox: nested-hw-virt is enabled but may not work on all CPUs
4. Mac: nested KVM is not available — use a Linux host for KVM workloads
