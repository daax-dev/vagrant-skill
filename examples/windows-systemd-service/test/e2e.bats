#!/usr/bin/env bats
# e2e.bats — end-to-end tests for windows-systemd-service example
#
#   cd examples/windows-systemd-service
#   vagrant up
#   bats test/e2e.bats
#   vagrant destroy -f
#
# All tests run commands inside the VM via `vagrant ssh -c`.

EXAMPLE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# ── Python ─────────────────────────────────────────────────────────────────────

@test "python3 is installed at /usr/bin/python3" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "test -x /usr/bin/python3"
  [ "$status" -eq 0 ]
}

@test "python3 is version 3.x" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "/usr/bin/python3 --version"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Python 3."* ]]
}

# ── Service user ───────────────────────────────────────────────────────────────

@test "demo system user exists" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "id demo"
  [ "$status" -eq 0 ]
}

@test "demo user has no login shell" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "getent passwd demo | cut -d: -f7"
  [ "$status" -eq 0 ]
  [ "$output" = "/usr/sbin/nologin" ]
}

# ── Unit file ──────────────────────────────────────────────────────────────────

@test "unit file exists" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "test -f /etc/systemd/system/demo-http.service"
  [ "$status" -eq 0 ]
}

@test "unit file ExecStart uses full python3 path" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "grep -q 'ExecStart=/usr/bin/python3 -m http.server 8000' /etc/systemd/system/demo-http.service"
  [ "$status" -eq 0 ]
}

@test "unit file WorkingDirectory is /srv/demo" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "grep -q 'WorkingDirectory=/srv/demo' /etc/systemd/system/demo-http.service"
  [ "$status" -eq 0 ]
}

@test "unit file runs as user demo" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "grep -q 'User=demo' /etc/systemd/system/demo-http.service"
  [ "$status" -eq 0 ]
}

@test "/srv/demo exists and is owned by demo" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "stat -c '%U' /srv/demo"
  [ "$status" -eq 0 ]
  [ "$output" = "demo" ]
}

@test "index.html is present in /srv/demo" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "test -f /srv/demo/index.html"
  [ "$status" -eq 0 ]
}

# ── systemd state ──────────────────────────────────────────────────────────────

@test "demo-http service is active" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "systemctl is-active demo-http"
  [ "$status" -eq 0 ]
  [ "$output" = "active" ]
}

@test "demo-http service is enabled (survives reboot)" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "systemctl is-enabled demo-http"
  [ "$status" -eq 0 ]
  [ "$output" = "enabled" ]
}

@test "demo-http process runs as demo user" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "ps -eo user,args | grep '[h]ttp.server 8000' | awk '{print \$1}'"
  [ "$status" -eq 0 ]
  [ "$output" = "demo" ]
}

@test "demo-http is listening on port 8000" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "ss -tlnp | grep -q ':8000'"
  [ "$status" -eq 0 ]
}

# ── HTTP ───────────────────────────────────────────────────────────────────────

@test "HTTP server returns 200 on port 8000" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "curl -so /dev/null -w '%{http_code}' http://localhost:8000"
  [ "$status" -eq 0 ]
  [ "$output" = "200" ]
}

@test "HTTP server serves index.html content" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "curl -sf http://localhost:8000"
  [ "$status" -eq 0 ]
  [[ "$output" == *"demo-http is running under systemd"* ]]
}

@test "journald has log entries for demo-http" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "journalctl -u demo-http --no-pager -n 5"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

# ── Resilience ─────────────────────────────────────────────────────────────────

@test "service restarts automatically after SIGKILL" {
  cd "$EXAMPLE_DIR"
  # RestartSec=2s in unit file — sleep 4 gives systemd time to restart
  run vagrant ssh -c "sudo systemctl kill --signal=SIGKILL demo-http && sleep 4 && systemctl is-active demo-http"
  [ "$status" -eq 0 ]
  [ "$output" = "active" ]
}

@test "service survives daemon-reload" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "sudo systemctl daemon-reload && systemctl is-active demo-http"
  [ "$status" -eq 0 ]
  [ "$output" = "active" ]
}

@test "service restarts cleanly via systemctl restart" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "sudo systemctl restart demo-http && sleep 2 && curl -sf http://localhost:8000 > /dev/null"
  [ "$status" -eq 0 ]
}
