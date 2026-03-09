# Changelog

## [0.1.0] - 2026-03-09

### Added
- macOS LaunchAgent-based watchdog for OpenClaw setups
- Health checks for:
  - OpenClaw gateway
  - a local companion app URL
- Recovery ladder:
  1. first failure -> log only
  2. second consecutive failure -> restart gateway + PM2 app
  3. third consecutive failure -> run `openclaw doctor --fix --non-interactive --yes`
- Persistent state file for consecutive-failure tracking
- Log files for watchdog runs and LaunchAgent stdout/stderr
- macOS-safe lock implementation using a lock directory (`mkdir`) instead of `flock`

### Notes
- Repository intentionally avoids any personal machine paths, usernames, chat ids, or machine-specific app names.
