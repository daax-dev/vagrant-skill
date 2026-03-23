#!/usr/bin/env bats
# e2e.bats — end-to-end tests for nginx-hardened example
#
#   vagrant up
#   bats test/e2e.bats
#   vagrant destroy -f
#
# All tests run commands inside the VM via `vagrant ssh -c`.

EXAMPLE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# ── nginx ──────────────────────────────────────────────────────────────────────

@test "nginx binary is present" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "which nginx"
  [ "$status" -eq 0 ]
}

@test "nginx service is active" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "systemctl is-active nginx"
  [ "$status" -eq 0 ]
  [[ "$output" == *"active"* ]]
}

@test "nginx is enabled (survives reboot)" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "systemctl is-enabled nginx"
  [ "$status" -eq 0 ]
  [[ "$output" == *"enabled"* ]]
}

@test "nginx returns HTTP 200 on port 80" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "curl -so /dev/null -w '%{http_code}' http://localhost"
  [ "$status" -eq 0 ]
  [[ "$output" == "200" ]]
}

@test "nginx serves the default welcome page" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "curl -sf http://localhost"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Welcome to nginx"* ]]
}

# ── iptables firewall ──────────────────────────────────────────────────────────

@test "iptables INPUT default policy is DROP" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "sudo iptables -L INPUT | head -1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"policy DROP"* ]]
}

@test "firewall ACCEPT rule exists for SSH (port 22)" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "sudo iptables -L INPUT -n"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dpt:22"* ]]
}

@test "firewall ACCEPT rule exists for HTTP (port 80)" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "sudo iptables -L INPUT -n"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dpt:80"* ]]
}

@test "firewall has no ACCEPT rule for port 8080" {
  cd "$EXAMPLE_DIR"
  # grep exits 1 when nothing matches — that's the pass condition here
  run vagrant ssh -c "sudo iptables -L INPUT -n | grep 'dpt:8080'"
  [ "$status" -ne 0 ]
}

@test "firewall has no ACCEPT rule for port 443 (not configured)" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "sudo iptables -L INPUT -n | grep 'dpt:443'"
  [ "$status" -ne 0 ]
}

@test "loopback interface is explicitly allowed" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "sudo iptables -L INPUT -n | grep -i 'lo\|loopback\|127.0.0.1'"
  [ "$status" -eq 0 ]
}

@test "ESTABLISHED/RELATED connections are accepted (return traffic)" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "sudo iptables -L INPUT -n"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ESTABLISHED"* ]]
}

# ── persistence ───────────────────────────────────────────────────────────────

@test "iptables rules are saved to disk" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "test -f /etc/iptables/rules.v4 && echo exists"
  [ "$status" -eq 0 ]
  [[ "$output" == *"exists"* ]]
}

@test "saved rules contain the DROP policy" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "grep -q ':INPUT DROP' /etc/iptables/rules.v4 && echo found"
  [ "$status" -eq 0 ]
  [[ "$output" == *"found"* ]]
}

@test "saved rules contain the SSH allow rule" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "grep -q 'dport 22' /etc/iptables/rules.v4 && echo found"
  [ "$status" -eq 0 ]
  [[ "$output" == *"found"* ]]
}

@test "netfilter-persistent service is enabled" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "systemctl is-enabled netfilter-persistent"
  [ "$status" -eq 0 ]
  [[ "$output" == *"enabled"* ]]
}
