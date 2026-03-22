#!/usr/bin/env bats
# Tests for Vagrantfile syntax and configuration.

VAGRANTFILE="$BATS_TEST_DIRNAME/../Vagrantfile"

@test "Vagrantfile exists" {
  [ -f "$VAGRANTFILE" ]
}

@test "Vagrantfile has valid Ruby syntax" {
  ruby -c "$VAGRANTFILE"
}

@test "Vagrantfile configures parallels provider" {
  grep -q 'config.vm.provider "parallels"' "$VAGRANTFILE"
}

@test "Vagrantfile configures libvirt provider" {
  grep -q 'config.vm.provider "libvirt"' "$VAGRANTFILE"
}

@test "Vagrantfile configures virtualbox provider" {
  grep -q 'config.vm.provider "virtualbox"' "$VAGRANTFILE"
}

@test "Vagrantfile warns about VirtualBox on Apple Silicon" {
  grep -q 'Apple Silicon' "$VAGRANTFILE"
}

@test "Vagrantfile uses bento/ubuntu-24.04 box" {
  grep -q 'bento/ubuntu-24.04' "$VAGRANTFILE"
}

@test "Vagrantfile enables nested KVM for libvirt" {
  grep -q 'host-passthrough' "$VAGRANTFILE"
  grep -q 'lv.nested = true' "$VAGRANTFILE"
}

@test "Vagrantfile enables nested VT-x for VirtualBox" {
  grep -q 'nested-hw-virt' "$VAGRANTFILE"
}

@test "Vagrantfile supports PROJECT_SRC env var" {
  grep -q 'PROJECT_SRC' "$VAGRANTFILE"
}

@test "Vagrantfile supports VM_CPUS env var" {
  grep -q 'VM_CPUS' "$VAGRANTFILE"
}

@test "Vagrantfile supports VM_MEMORY env var" {
  grep -q 'VM_MEMORY' "$VAGRANTFILE"
}

@test "Vagrantfile does NOT reference nanofuse" {
  ! grep -qi 'nanofuse' "$VAGRANTFILE"
}

@test "Vagrantfile does NOT reference firecracker" {
  ! grep -qi 'firecracker' "$VAGRANTFILE"
}
