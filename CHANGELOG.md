# Changelog

All notable changes to this project will be documented in this file.

## [1.0.7] - 2026-03-04

### Added
- Master/worker deployment role model (`DEPLOY_ROLE=master|worker`).
- Master-oriented command listener with remote query support via SSH.
- New Telegram commands:
  - `/nodes`
  - `/traffic <node>`
  - `/selfcheck <node>`
- Node inventory template: `nodes.example.json`.

### Changed
- Installer role-aware behavior:
  - master enables bot listener by default
  - worker disables bot listener by default
- Report message now includes host node name.
- Docs restructured around multi-node best practice.

## [1.0.6] - 2026-03-04

### Added
- Non-interactive env-driven install mode in `install.sh` via:
  - `SERVER_NAME`
  - `LIMIT_GB`
  - `CHAT_ID`
  - `BOT_TOKEN`
  - optional `IFACE`, `BILLING_DAY`, `BILLING_HMS`, `SCHEDULE_MODE`, `ENABLE_BOT_LISTENER`
- Supports one-line fully automated deployment without manual prompts.

## [1.0.4] - 2026-03-04

### Added
- Telegram command listener (`bot_listener.py`) with commands:
  - `/traffic`
  - `/traffic_send`
  - `/selfcheck`
  - `/help`
- systemd service: `systemd/traffic-local-bot.service`
- Installer flag: `ENABLE_BOT_LISTENER=true`
- Interactive installer can optionally enable command listener.

### Changed
- Uninstaller now also removes bot listener service.
- Docs updated with Telegram command workflow.

## [1.0.3] - 2026-03-04

### Added
- `--self-check` mode in `report.py`:
  - config validation
  - token file checks
  - vnstat/interface checks
  - Telegram API getMe connectivity check
  - scheduler presence check (cron/systemd)
- Optional `--show-config` with self-check output.

### Changed
- Documentation updated with self-check workflow.

## [1.0.2] - 2026-03-04

### Added
- Interactive installer mode via `INIT=true`.
- Interactive prompts for:
  - server name
  - network interface (`auto` supported)
  - monthly limit
  - billing day/time
  - Telegram chat_id
  - Telegram bot token
- Post-init test send (`report.py --send`) in installer.
- Installer schedule selection: `cron` / `systemd` / `none`.

### Fixed
- Installer output flow made safer and more robust for one-line execution.

## [1.0.1] - 2026-03-04

### Added
- Auto network interface support via `"interface": "auto"`.
- Optional `systemd` scheduling templates:
  - `systemd/traffic-local-report.service`
  - `systemd/traffic-local-report.timer`
- Installer flag: `ENABLE_SYSTEMD_TIMER=true`.

### Changed
- Improved runtime error messages.

## [1.0.0] - 2026-03-04

### Added
- Initial public release.
