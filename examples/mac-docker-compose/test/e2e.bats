#!/usr/bin/env bats
# e2e.bats — end-to-end tests for mac-docker-compose example
#
#   cd examples/mac-docker-compose
#   vagrant up
#   bats test/e2e.bats
#   vagrant destroy -f
#
# All tests run commands inside the VM via `vagrant ssh -c`.

EXAMPLE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
STACK_DIR="/opt/demo-stack"

# ── Docker daemon ──────────────────────────────────────────────────────────────

@test "docker daemon is running" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "docker info > /dev/null 2>&1"
  [ "$status" -eq 0 ]
}

@test "docker compose plugin is available" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "docker compose version"
  [ "$status" -eq 0 ]
}

# ── Container state ────────────────────────────────────────────────────────────

@test "demo-nginx container is running" {
  cd "$EXAMPLE_DIR"
  # Use --format + grep -Fx for exact match — avoids --filter name= substring pitfall
  # (docker ps --filter name=nginx also matches my-nginx-proxy-1 etc.)
  run vagrant ssh -c "docker ps --format '{{.Names}}' | grep -Fx 'demo-nginx'"
  [ "$status" -eq 0 ]
}

@test "demo-python-api container is running" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "docker ps --format '{{.Names}}' | grep -Fx 'demo-python-api'"
  [ "$status" -eq 0 ]
}

@test "python-api healthcheck is healthy" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "docker inspect demo-python-api --format '{{.State.Health.Status}}'"
  [ "$status" -eq 0 ]
  [ "$output" = "healthy" ]
}

@test "exactly two containers are running" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "docker compose -f ${STACK_DIR}/docker-compose.yml ps --status running --quiet | wc -l | tr -d ' '"
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
}

# ── HTTP endpoints ─────────────────────────────────────────────────────────────

@test "nginx returns HTTP 200 on port 80" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "curl -so /dev/null -w '%{http_code}' http://localhost"
  [ "$status" -eq 0 ]
  [ "$output" = "200" ]
}

@test "nginx serves the default static page" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "curl -sf http://localhost"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Welcome to nginx"* ]]
}

@test "python API returns JSON on /api/" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "curl -sf http://localhost/api/"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello from python-api"* ]]
}

@test "/healthz returns status ok" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "curl -sf http://localhost/healthz"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status": "ok"'* ]]
}

@test "API response is valid JSON" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "curl -sf http://localhost/api/ | python3 -c 'import sys,json; d=json.load(sys.stdin); exit(0 if \"message\" in d else 1)'"
  [ "$status" -eq 0 ]
}

@test "port 8000 is not published to host NIC (expose-only)" {
  cd "$EXAMPLE_DIR"
  # 'expose' makes port 8000 available inside the Docker network only.
  # 'ports' publishes to 0.0.0.0 on the VM. Verify 8000 has no 0.0.0.0 binding.
  run vagrant ssh -c "ss -tlnp | grep ':8000'"
  # ss finds nothing for expose-only ports -> grep exits 1 -> status != 0
  [ "$status" -ne 0 ]
}

# ── Stack management ───────────────────────────────────────────────────────────

@test "compose down and up is idempotent" {
  cd "$EXAMPLE_DIR"
  run vagrant ssh -c "cd ${STACK_DIR} && docker compose down && docker compose up -d && sleep 5 && curl -sf http://localhost > /dev/null"
  [ "$status" -eq 0 ]
}

@test "containers restart after docker daemon restart" {
  cd "$EXAMPLE_DIR"
  # restart: unless-stopped means containers come back after docker daemon restart
  run vagrant ssh -c "sudo systemctl restart docker && sleep 8 && curl -sf http://localhost > /dev/null"
  [ "$status" -eq 0 ]
}
