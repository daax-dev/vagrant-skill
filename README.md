# vagrant-skill

**Disposable VMs for safe testing — Claude Code + OpenClaw skill**

| | |
|---|---|
| **Repo** | [daax-dev/vagrant-skill](https://github.com/daax-dev/vagrant-skill) |
| **Stack** | Vagrant, Shell, Ubuntu 24.04 |
| **Skill** | [Agent Skills](https://agentskills.io) standard (Claude Code + OpenClaw) |

## What It Does

Provides disposable, fully-provisioned Ubuntu 24.04 VMs for safe experimentation:

- **Full sudo access** — agents and humans can do anything without risk to the host
- **Pre-installed tooling** — Go 1.24, Docker, mage, build-essential, network tools
- **Nested KVM** — hardware virtualization passthrough (Linux with libvirt)
- **Configurable** — sync any project, adjust CPU/RAM/Go version via env vars
- **Destroy and recreate** — VMs are ephemeral, nothing persists unless you want it
- **Dual skill** — works as both a Claude Code skill and an OpenClaw skill
- **Cross-platform** — tested on Mac (Parallels), Linux (libvirt), with VirtualBox as fallback

---

## Platform Setup

### Mac (Apple Silicon — M1/M2/M3/M4) — Recommended: Parallels

VirtualBox on Apple Silicon is experimental and unreliable. **Use Parallels.**

```bash
# 1. Install Parallels Desktop (requires license)
#    Download from https://www.parallels.com/products/desktop/

# 2. Install Vagrant
brew install --cask vagrant

# 3. Install the Parallels provider plugin
vagrant plugin install vagrant-parallels

# 4. Clone and start
git clone git@github.com:daax-dev/vagrant-skill.git
cd vagrant-skill
vagrant up --provider=parallels
```

**Verified working:** macOS 26.3, Apple Silicon (arm64), Parallels Desktop, Vagrant 2.4.9, bento/ubuntu-24.04 arm64 box. Setup provisions Go 1.24.3 (arm64), Docker, mage. 11/11 checks pass.

**KVM note:** Nested KVM is not available on Mac (no `/dev/kvm`). The VM still provides Docker, Go, mage, and full sudo. If you need nested KVM (e.g., for Firecracker microVM testing), use a Linux host.

### Mac (Intel) — VirtualBox

```bash
# 1. Install VirtualBox
brew install --cask virtualbox

# 2. Install Vagrant
brew install --cask vagrant

# 3. Clone and start
git clone git@github.com:daax-dev/vagrant-skill.git
cd vagrant-skill
vagrant up --provider=virtualbox
```

### Linux — Recommended: libvirt/KVM

This is the most capable setup — includes nested KVM for microVM testing.

```bash
# 1. Install KVM + libvirt
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

# 2. Install Vagrant + libvirt plugin
sudo apt-get install -y vagrant
vagrant plugin install vagrant-libvirt

# 3. Clone and start
git clone git@github.com:daax-dev/vagrant-skill.git
cd vagrant-skill
vagrant up --provider=libvirt
```

**Nested KVM** is automatically enabled (`cpu_mode: host-passthrough`). Verify on your host:
```bash
# Host must have KVM
test -e /dev/kvm && echo "KVM OK"

# After vagrant up, verify nested KVM inside VM
vagrant ssh -c "test -e /dev/kvm && echo 'Nested KVM OK'"
```

### Windows (WSL2) — VirtualBox

```bash
# 1. Install VirtualBox on Windows (not inside WSL2)
#    Download from https://www.virtualbox.org/wiki/Downloads

# 2. Inside WSL2, install Vagrant
sudo apt-get install -y vagrant

# 3. Tell Vagrant to use the Windows VirtualBox
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"

# 4. Clone and start
git clone git@github.com:daax-dev/vagrant-skill.git
cd vagrant-skill
vagrant up --provider=virtualbox
```

---

## Quick Start

```bash
# Start VM (no project sync)
vagrant up

# Start VM with your project synced into /project
PROJECT_SRC=~/myproject vagrant up

# Run commands inside (agent workflow — no interactive SSH needed)
vagrant ssh -c "sudo apt-get install -y something"
vagrant ssh -c "cd /project && make test"

# Sync code changes from host
vagrant rsync

# Destroy and start fresh
vagrant destroy -f
```

## Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `PROJECT_SRC` | auto-detect | Host directory to sync into VM at `/project` |
| `VM_CPUS` | 4 | Number of vCPUs |
| `VM_MEMORY` | 4096 | RAM in MB |
| `VM_NAME` | vagrant-skill-dev | VM hostname |
| `GO_VERSION` | 1.24.3 | Go version to install |

```bash
PROJECT_SRC=~/myapp VM_CPUS=8 VM_MEMORY=8192 vagrant up
```

---

## Install as a Skill

### Claude Code

```bash
# Global (available in all projects)
git clone git@github.com:daax-dev/vagrant-skill.git ~/.claude/skills/vagrant

# Per-project
git clone git@github.com:daax-dev/vagrant-skill.git .claude/skills/vagrant
```

Then use `/vagrant` in Claude Code.

### OpenClaw

```bash
# Manual install
git clone git@github.com:daax-dev/vagrant-skill.git ~/.openclaw/skills/vagrant
```

---

## Using as a Consumer

Projects that depend on vagrant-skill for dev environments (e.g., nanofuse):

```bash
# From vagrant-skill directory, point to your project
PROJECT_SRC=~/path/to/your-project vagrant up

# Then run project-specific setup inside the VM
vagrant ssh -c "sudo /project/scripts/my-setup.sh"
```

---

## What's In The VM

| Tool | Version | Notes |
|------|---------|-------|
| Ubuntu | 24.04 LTS | bento/ubuntu-24.04 box |
| Go | 1.24.3 | arm64 or amd64 auto-detected |
| Docker | Latest CE | Daemon running, vagrant user in docker group |
| mage | Latest | Go build tool |
| build-essential | System | gcc, make, etc. |
| Network tools | System | iptables, dnsmasq, iproute2, dig, net-tools |
| KVM tools | System | Only on Linux with nested KVM |
| sqlite3 | System | With libsqlite3-dev |
| jq, curl, git | System | Standard utilities |

---

## Testing

```bash
# Lint (shellcheck + ruby syntax)
make lint

# Unit tests (44 bats tests)
make test

# Full integration (spins up VM, provisions, verifies, destroys)
make test-integration

# All
make test-all
```

## Project Structure

```
vagrant-skill/
├── Vagrantfile                    # Multi-provider (Parallels, libvirt, VirtualBox)
├── SKILL.md                       # Agent Skills standard (Claude Code + OpenClaw)
├── .claude/skills/vagrant/        # Claude Code skill copy
├── scripts/
│   ├── setup.sh                   # Provisioner: system deps, Docker, Go, mage, KVM
│   └── verify.sh                  # Validation suite (11 checks)
├── docs/                          # Reference documentation
├── test/                          # bats-core tests (44 tests)
├── Makefile                       # lint, test, test-integration, up, destroy
├── README.md
├── CLAUDE.md
└── LICENSE                        # Apache 2.0
```

## License

Apache 2.0
