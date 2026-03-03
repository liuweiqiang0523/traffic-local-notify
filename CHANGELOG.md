# Changelog

All notable changes to this project will be documented in this file.

## [1.0.9] - 2026-03-04

### Added
- 6-node ready-to-use templates:
  - `examples/nodes.6.example.json`
  - `examples/deploy-6.sh`
- Documentation updated with template references.

## [1.0.8] - 2026-03-04

### Added
- Remote query fallback in `bot_listener.py`:
  - classifies SSH failure reasons
  - provides actionable troubleshooting hints
  - falls back to master local result so commands always return feedback
- One-command cluster bootstrap script: `setup-cluster.sh`
  - `ROLE=master|worker` mode
  - env-driven deployment
- Uninstall workflow documented (one-line uninstall via raw script).

### Changed
- Documentation now centers around master-worker operations and one-command usage.

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
- Installer role-aware behavior.
- Report message now includes host node name.

## [1.0.6] - 2026-03-04

### Added
- Non-interactive env-driven install mode.

## [1.0.4] - 2026-03-04

### Added
- Telegram command listener (`bot_listener.py`).

## [1.0.3] - 2026-03-04

### Added
- `--self-check` mode in `report.py`.

## [1.0.2] - 2026-03-04

### Added
- Interactive installer mode via `INIT=true`.

## [1.0.1] - 2026-03-04

### Added
- Auto network interface support and improved errors.

## [1.0.0] - 2026-03-04

### Added
- Initial public release.
