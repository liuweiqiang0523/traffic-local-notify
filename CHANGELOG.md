# Changelog

All notable changes to this project will be documented in this file.

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
- Improved runtime error messages:
  - vnstat command failures
  - JSON parse failures
  - missing fields / invalid config
  - Telegram push failures
- README and README.zh-CN updated with cron + systemd modes.
- Installer hardened for both `git clone` and `curl` one-line mode.

## [1.0.0] - 2026-03-04

### Added
- Initial public release.
- One-line installer support: `bash <(curl -fsSL .../install.sh)`.
- Local vnStat-based monthly traffic reporting (`report.py`).
- Telegram notification support with threshold alerts.
- Config template with billing cycle and alert levels.
- Uninstaller script.
