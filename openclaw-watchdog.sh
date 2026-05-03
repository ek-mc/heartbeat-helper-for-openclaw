#!/bin/bash
set -euo pipefail

STATE_DIR="$HOME/.openclaw/watchdog"
LOG_DIR="$STATE_DIR/logs"
STATE_FILE="$STATE_DIR/state.env"
LOCK_DIR="$STATE_DIR/watchdog.lockdir"
APP_URL="${APP_URL:-http://localhost:3000/}"
APP_PM2_NAME="${APP_PM2_NAME:-my-local-app}"
MAX_APP_TIME="${MAX_APP_TIME:-8}"
MAX_GATEWAY_TIME="${MAX_GATEWAY_TIME:-8}"
FAILURES_BEFORE_RESTART="${FAILURES_BEFORE_RESTART:-2}"
FAILURES_BEFORE_DOCTOR="${FAILURES_BEFORE_DOCTOR:-3}"
FAILURES_BEFORE_FIX="${FAILURES_BEFORE_FIX:-4}"
ENABLE_DOCTOR_FIX="${ENABLE_DOCTOR_FIX:-true}"
DRY_RUN="${DRY_RUN:-false}"

mkdir -p "$LOG_DIR"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

TS="$(date '+%Y-%m-%d %H:%M:%S')"
LOG_FILE="$LOG_DIR/watchdog.log"

log() {
  echo "[$TS] $*" | tee -a "$LOG_FILE"
}

dry_run_log() {
  log "[DRY RUN] would: $*"
}

load_state() {
  failure_count=0
  last_phase="none"
  last_reason=""
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  fi
}

save_state() {
  cat > "$STATE_FILE" <<EOF
failure_count=${failure_count}
last_phase='${last_phase}'
last_reason='${last_reason}'
EOF
}

check_gateway() {
  if openclaw status >/tmp/openclaw-watchdog-status.txt 2>&1; then
    return 0
  fi
  return 1
}

check_app() {
  local code
  code="$(curl -sS -m "$MAX_APP_TIME" -o /tmp/openclaw-watchdog-app.html -w '%{http_code}' "$APP_URL" || true)"
  [[ "$code" == "200" ]]
}

restart_gateway() {
  log "Restarting OpenClaw gateway"
  openclaw gateway restart >> "$LOG_FILE" 2>&1 || true
  sleep 8
}

restart_app() {
  log "Restarting PM2 app ${APP_PM2_NAME}"
  pm2 restart "$APP_PM2_NAME" >> "$LOG_FILE" 2>&1 || true
  sleep 8
}

run_doctor() {
  log "Running openclaw doctor --non-interactive"
  openclaw doctor --non-interactive >> "$LOG_FILE" 2>&1 || true
}

run_doctor_fix() {
  log "Running openclaw doctor --fix --non-interactive --yes"
  openclaw doctor --fix --non-interactive --yes >> "$LOG_FILE" 2>&1 || true
}

if [[ "$DRY_RUN" == "true" ]]; then
  log "DRY RUN mode enabled — no restarts or doctor commands will be executed"
fi

load_state

issues=()
if ! check_gateway; then
  issues+=("gateway")
fi
if ! check_app; then
  issues+=("app:$APP_URL")
fi

if [[ ${#issues[@]} -eq 0 ]]; then
  if [[ "${failure_count}" -gt 0 ]]; then
    log "Recovered. Previous failures: ${failure_count}"
  fi
  failure_count=0
  last_phase="healthy"
  last_reason=""
  save_state
  exit 0
fi

failure_count=$((failure_count + 1))
last_reason="$(IFS=,; echo "${issues[*]}")"
log "Health check failed (#${failure_count}): ${last_reason}"

if [[ "$failure_count" -ge "$FAILURES_BEFORE_RESTART" && "$last_phase" != "restart" && "$last_phase" != "doctor" && "$last_phase" != "doctor_fix" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    dry_run_log "restart gateway + PM2 app (${APP_PM2_NAME})"
  else
    restart_gateway
    restart_app
  fi
  last_phase="restart"
fi

if [[ "$ENABLE_DOCTOR_FIX" == "true" && "$failure_count" -ge "$FAILURES_BEFORE_DOCTOR" && "$last_phase" != "doctor" && "$last_phase" != "doctor_fix" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    dry_run_log "openclaw doctor --non-interactive"
  else
    run_doctor
  fi
  last_phase="doctor"
fi

if [[ "$ENABLE_DOCTOR_FIX" == "true" && "$failure_count" -ge "$FAILURES_BEFORE_FIX" && "$last_phase" != "doctor_fix" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    dry_run_log "openclaw doctor --fix --non-interactive --yes"
  else
    run_doctor_fix
  fi
  last_phase="doctor_fix"
fi

save_state
exit 0
