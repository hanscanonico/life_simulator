# Helpers shared by deploy/deploy and deploy/ensure_up, both of which source this
# from the repo root. Sourced, never executed: it defines and never acts.

compose="docker compose -f deploy/docker-compose.yml"

# Read once: it also fails the caller early on an unusable compose file.
services=$($compose config --services)

# A container whose start failed — a dependency that never turned healthy, an
# allocation refused while the build's memory was still resident, a deploy job
# cancelled mid `up -d` — is left in `Created`, a state `restart: unless-stopped`
# never acts on because the container was never started. `up -d` is not a
# reliable witness of that, so every service is read back from the daemon by name.
not_running() {
  local service container state
  while read -r service; do
    [ -n "$service" ] || continue
    container=$($compose ps -aq "$service" 2>/dev/null | head -1)
    state=""
    if [ -n "$container" ]; then
      state=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || true)
    fi
    [ "$state" = running ] || echo "$service: ${state:-absent}"
  done <<<"$services"
}

# 200 from /up is the app's own answer; the state sweep catches the services
# that answer for nothing — a `Created` app, or a cloudflared the swap left
# behind while the app itself is fine.
wait_healthy() {
  local down
  echo "Waiting for the whole stack to come up..."
  for _ in $(seq 1 45); do
    if curl -fsS http://127.0.0.1:8070/up >/dev/null 2>&1; then
      down=$(not_running)
      if [ -z "$down" ]; then
        return 0
      fi
    fi
    sleep 2
  done
  return 1
}

report_stack() {
  {
    $compose ps -a || true
    not_running | sed 's/^/Not running: /'
    echo "--- app, last 50 log lines ---"
    $compose logs --tail 50 --no-color app 2>&1 || true
  } >&2
}
