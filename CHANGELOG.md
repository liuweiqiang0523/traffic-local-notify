# Changelog

All notable changes to this project will be documented in this file.

## [1.3.0] - 2026-03-04

### Added
- Billing-centric commands:
  - `trafficctl set-billing <day> <HH:MM:SS>`
  - `trafficctl show-billing`

### Improved
- End-to-end docs now emphasize per-server billing policy (`billing_day + billing_hms`) as the primary truth.

## [1.2.6] - 2026-03-04

### Fixed
- Removed static billing-cycle defaults in one-line installs.
- `setup-cluster.sh` now defaults `BILLING_DAY/BILLING_HMS` to current time if not provided.
- `install.sh` env-mode defaults updated similarly; interactive mode now shows current time as default.

## [1.2.5] - 2026-03-04

### Changed
- `quick-install.sh --defaults` no longer auto-fills `LIMIT_GB=25600`.
- Installer now always asks for `LIMIT_GB` explicitly, so each server can have its own quota.

## [1.2.4] - 2026-03-04

### Added
- `trafficctl rebase now`:
  - set `billing_day/billing_hms` to current time
  - backup and reset `state.json` safely
  - print immediate dry-run result

### Why
- Align cycle start with real billing situation without manual file edits.

## [1.2.3] - 2026-03-04

### Added
- `scripts/lib/install.sh`: shared install helpers, sourced by installer
- `trafficctl why`: common failure reasons and quick fixes

### Changed
- Installer now supports `NODES_JSON_B64` / `NODES_JSON_URL` payload via shared helper path.
- Further internal modularization for maintainability (same external commands).

## [1.2.2] - 2026-03-04

### Changed
- Internal refactor for cluster bootstrap:
  - extracted reusable cluster helper module to `scripts/lib/cluster.sh`
  - `setup-cluster.sh` now reuses shared module (local mode + curl mode)
- `quick-install.sh` now asks `ALLOWED_USER_IDS` to enable allowlist during first install.

## [1.2.1] - 2026-03-04

### Added
- `trafficctl doctor` enhancements:
  - nodes.json schema validation
  - optional SSH connectivity check for each node
  - permission checks for `/opt/traffic-local` and token file
  - allowlist (`allowed_user_ids`) hint
- `trafficctl fix` command:
  - `fix all|perms|vnstat|timer|bot` for common repair flows

## [1.2.0] - 2026-03-04

### Added
- `trafficctl` helper CLI for beginner operations and diagnostics:
  - `doctor`, `status`, `report`, `send`, `restart`, `logs`
- Installer now deploys `trafficctl` to `/usr/local/bin/trafficctl`.
- `quick-install.sh --menu` mode (install or run doctor).

### Changed
- Install completion hints now include `trafficctl doctor`.

## [1.1.0] - 2026-03-04

### Changed
- README (EN/ZH) rewritten for beginner-first onboarding.
- Simplified docs structure and highlighted single-command defaults flow.

### Added
- `docs/GETTING_STARTED.zh-CN.md`
- `docs/GETTING_STARTED.md`

## [1.0.14] - 2026-03-04

### Added
- P0 hardening:
  - bot listener singleton lock (prevent duplicate consumers)
  - Telegram command user allowlist via `allowed_user_ids`
  - version-pinned installer support (`VERSION=<tag>`)
- New command: `/summary` to aggregate usage across master + nodes.

## [1.0.13] - 2026-03-04

### Added
- `quick-install.sh --defaults` mode:
  - asks only minimal required inputs
  - uses sensible defaults for other fields

## [1.0.12] - 2026-03-04

### Added
- `quick-install.sh`: truly single-command interactive installer
  - prompts role (master/worker)
  - prompts required settings
  - executes cluster setup automatically

## [1.0.11] - 2026-03-04

### Added
- Worker auto-registration to master nodes inventory in `setup-cluster.sh`:
  - `MASTER_HOST`, `MASTER_USER`, `MASTER_PORT`, `MASTER_KEY`
  - auto-detect worker public IP (`NODE_IP` fallback)
  - updates/appends master `/opt/traffic-local/nodes.json` via SSH
  - best-effort restart of master bot listener
- Non-blocking fallback behavior if registration fails (installation continues).

## [1.0.10] - 2026-03-04

### Added
- setup-cluster enhancements:
  - auto server name fallback (`hostname-role`)
  - master supports one-shot nodes provisioning via `NODES_JSON_B64` or `NODES_JSON_URL`
- docs updated for true one-liner master deployment.

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
