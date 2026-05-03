# ❤️ Heartbeat Helper for OpenClaw

A tiny macOS reliability helper for **OpenClaw** + a local companion app.

Built for people who love OpenClaw and want a simple safety net when a gateway or local app silently wedges.

## What it does

Every 5 minutes it checks:
- OpenClaw gateway health via `openclaw status`
- Local app health via HTTP (default: `http://localhost:3000/`)

## Recovery ladder

1. **First failure** → log only
2. **Second consecutive failure** → restart gateway + PM2 app
3. **Third consecutive failure** → run `openclaw doctor --non-interactive` (diagnose only, no changes)
4. **Fourth consecutive failure** → run `openclaw doctor --fix --non-interactive --yes`

This keeps the behavior graduated: cheap recovery first, diagnosis before any destructive fix, and the aggressive `--fix` only as a last resort after repeated failures.

## Why this exists

Sometimes the problem is not sleep. It can be:
- gateway weirdness
- a stuck local app
- a broken service state
- a transient provider/runtime issue that leaves things half-alive

This helper gives your setup a small “heartbeat” and a recovery ladder.

## Features

- ❤️ Simple reliability-first recovery flow
- macOS LaunchAgent friendly
- No `flock` dependency (uses lock-dir instead)
- Persistent failure counting via state file
- Plain shell script, easy to audit
- Companion app URL + PM2 app name are configurable

## Files

- `openclaw-watchdog.sh`
- `CHANGELOG.md`
- `LICENSE`
- `.gitignore`

## Configuration

Environment variables:

- `APP_URL` → default: `http://localhost:3000/`
- `APP_PM2_NAME` → default: `my-local-app`
- `FAILURES_BEFORE_RESTART` → default: `2`
- `FAILURES_BEFORE_DOCTOR` → default: `3`
- `FAILURES_BEFORE_FIX` → default: `4`
- `ENABLE_DOCTOR_FIX` → default: `true`
- `DRY_RUN` → default: `false` — set to `true` to log what the watchdog *would* do without restarting anything

## Dry run

Useful for testing the script safely on a live machine before deploying it for real:

```bash
DRY_RUN=true bash openclaw-watchdog.sh
```

With `DRY_RUN=true` the script still runs health checks and tracks failure counts, but all recovery actions (restart, doctor, doctor --fix) are replaced with log lines prefixed `[DRY RUN] would:`. No processes are touched.

## Example LaunchAgent

Create:

`~/Library/LaunchAgents/ai.openclaw.watchdog.plist`

Example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>ai.openclaw.watchdog</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/ABSOLUTE/PATH/TO/openclaw-watchdog.sh</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>StartInterval</key>
  <integer>300</integer>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>APP_URL</key>
    <string>http://localhost:3000/</string>
    <key>APP_PM2_NAME</key>
    <string>my-local-app</string>
    <key>ENABLE_DOCTOR_FIX</key>
    <string>true</string>
  </dict>
</dict>
</plist>
```

Load it:

```bash
launchctl load -w ~/Library/LaunchAgents/ai.openclaw.watchdog.plist
```

## State + logs

By default:

- state: `~/.openclaw/watchdog/state.env`
- logs: `~/.openclaw/watchdog/logs/`

## Privacy / safety

This repository is intentionally generic:
- no usernames
- no chat ids
- no private machine names
- no hardcoded personal app names
- no hardcoded personal localhost ports beyond generic examples

## Notes

- `openclaw doctor --fix` is intentionally not the first step.
- First, try cheap recovery (restart).
- Then run a plain `doctor` pass to surface diagnostics without making changes.
- Only escalate to `doctor --fix` after repeated failures.

## License

MIT
