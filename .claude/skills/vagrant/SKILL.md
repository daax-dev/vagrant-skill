---
name: vagrant
description: Disposable VMs for safe testing — full sudo, nested KVM, destroy and recreate. Use when you need a sandbox to build, test, or break things without affecting the host.
version: 0.1.0
metadata:
  openclaw:
    requires:
      bins:
        - vagrant
      anyBins:
        - VBoxManage
        - virsh
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

Before using this workflow, verify one of these providers is available:

```bash
# Linux (preferred — nested KVM)
command -v vagrant && vagrant plugin list | grep libvirt

# Mac / Windows WSL2
command -v vagrant && command -v VBoxManage
```

### Location

The Vagrant environment lives at:
```
vagrant-skill/
  Vagrantfile       # Multi-provider (libvirt + VirtualBox)
  scripts/
    setup.sh        # Provisions: system deps, Docker, Go, mage, KVM tools
    verify.sh       # Validation suite
```

---

## Core Workflow

### 1. Provision the VM (first time or clean slate)

```bash
cd vagrant-skill

# Basic — no project sync
vagrant up

# With a project synced into the VM at /project
PROJECT_SRC=/path/to/your/project vagrant up
```

This gives you a VM with:
- Ubuntu 24.04
- Go + mage build system
- Docker
- Network tools (iptables, dnsmasq, iproute2)
- KVM tools (if nested KVM available on host)
- Full sudo

### 2. Run Commands Inside the VM

**All commands use `vagrant ssh -c` from the host.** You never need to `vagrant ssh` interactively.

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

### 3. Iterate on Code Changes

When you modify source on the host:

```bash
vagrant rsync                                    # sync changes to VM
vagrant ssh -c "cd /project && make build"       # rebuild
vagrant ssh -c "cd /project && make test"        # test
```

This is fast (~10s for rsync + rebuild) vs. full reprovision.

### 4. Tear Down

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

## What's Inside the VM

| Path | Contents |
|------|----------|
| `/project` | Source code (rsynced from host, if PROJECT_SRC set) |
| `/vagrant-scripts` | Setup and verify scripts |
| `/usr/local/go/bin/go` | Go toolchain |
| `/usr/local/bin/mage` | Mage build tool |

## Safety Guarantees

- **No host sudo required** — all privileged operations are inside the VM
- **Fully disposable** — `vagrant destroy -f` removes everything
- **Idempotent provisioning** — `vagrant provision` is safe to re-run
- **Isolated networking** — VM has its own network stack
- **Source is rsynced** — VM gets a copy; your host repo is never modified by the VM
- **No persistent state** — destroying the VM removes all data

## Troubleshooting

```bash
# VM won't boot
vagrant up --debug 2>&1 | tail -50

# Re-sync source without full reprovision
vagrant rsync

# Check what provider is being used
vagrant status

# KVM not available inside VM
# Ensure host has: cpu_mode = "host-passthrough" (libvirt) or nested-hw-virt (VBox)
```
