# -*- mode: ruby -*-
# vagrant-skill — Disposable dev/test VM
#
# Gives AI agents (Claude Code, OpenClaw) and humans full sudo in a
# disposable VM to build, test, and break things without host risk.
#
# Providers (auto-detected by Vagrant, or force with --provider):
#   - parallels  (Mac Apple Silicon — recommended for M1/M2/M3/M4)
#   - libvirt    (Linux — preferred, nested KVM for microVM testing)
#   - virtualbox (Linux, Mac Intel, Windows — NOT recommended on Apple Silicon)
#
# Syncs a project directory into the VM. Set PROJECT_SRC to override:
#   PROJECT_SRC=~/myproject vagrant up
#
# Usage:
#   vagrant up                    # provision + verify
#   vagrant ssh                   # interactive shell (full sudo)
#   vagrant ssh -c "sudo ..."    # run commands from host (agent workflow)
#   vagrant destroy -f            # tear down and start fresh
#   vagrant provision             # re-run setup + verify without rebuild

# ─── Project source resolution ───────────────────────────────────────────────
# Priority: PROJECT_SRC env var > parent directory with go.mod/package.json > none
SCRIPT_DIR = File.dirname(File.expand_path(__FILE__))
PROJECT_SRC = if ENV["PROJECT_SRC"]
    ENV["PROJECT_SRC"]
  elsif File.exist?(File.join(SCRIPT_DIR, "..", "go.mod")) ||
        File.exist?(File.join(SCRIPT_DIR, "..", "package.json")) ||
        File.exist?(File.join(SCRIPT_DIR, "..", "Makefile"))
    File.expand_path(File.join(SCRIPT_DIR, ".."))
  else
    nil
  end

if PROJECT_SRC
  puts "Project source: #{PROJECT_SRC}"
else
  puts "No project source detected (set PROJECT_SRC to sync a project into the VM)"
end

# ─── VM Configuration ────────────────────────────────────────────────────────
VM_CPUS   = Integer(ENV["VM_CPUS"]   || 4)
VM_MEMORY = Integer(ENV["VM_MEMORY"] || 4096)
VM_NAME   = ENV["VM_NAME"] || "vagrant-skill-dev"

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.box_check_update = false
  config.vm.hostname = VM_NAME
  config.vm.boot_timeout = 300
  config.ssh.forward_agent = true

  # ─── Provider: Parallels (Mac Apple Silicon — recommended) ───────────────
  # Install: brew install --cask parallels && vagrant plugin install vagrant-parallels
  config.vm.provider "parallels" do |prl|
    prl.cpus   = VM_CPUS
    prl.memory = VM_MEMORY
    prl.name   = VM_NAME
    prl.update_guest_tools = true
  end

  # ─── Provider: libvirt (Linux — preferred, nested KVM) ──────────────────
  # Install: apt-get install vagrant-libvirt (or vagrant plugin install vagrant-libvirt)
  config.vm.provider "libvirt" do |lv|
    lv.cpus   = VM_CPUS
    lv.memory = VM_MEMORY
    lv.cpu_mode = "host-passthrough"   # nested KVM
    lv.nested = true
    lv.default_prefix = "vagrant_skill_"
  end

  # ─── Provider: VirtualBox (Linux, Mac Intel, Windows) ───────────────────
  # WARNING: VirtualBox on Apple Silicon is experimental and very slow.
  #          Use Parallels on Mac M-series instead.
  config.vm.provider "virtualbox" do |vb|
    vb.cpus   = VM_CPUS
    vb.memory = VM_MEMORY
    vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
    vb.name = VM_NAME
  end

  # ─── Sync project source (if detected) ──────────────────────────────────
  if PROJECT_SRC
    config.vm.synced_folder PROJECT_SRC, "/project", type: "rsync",
      rsync__exclude: [
        ".git/",
        "node_modules/",
        "vendor/",
        "bin/",
        "dist/",
        "build/",
        ".next/",
        "coverage.out",
        "coverage.html",
      ]
  end

  # Sync vagrant-skill scripts into the VM
  config.vm.synced_folder ".", "/vagrant-scripts"

  # ─── Provision: install deps ─────────────────────────────────────────────
  config.vm.provision "setup", type: "shell" do |s|
    s.path = "scripts/setup.sh"
    s.privileged = true
  end

  # ─── Provision: verify everything works ──────────────────────────────────
  config.vm.provision "verify", type: "shell" do |s|
    s.path = "scripts/verify.sh"
    s.privileged = true
  end
end
