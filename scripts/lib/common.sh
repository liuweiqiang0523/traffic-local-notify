#!/usr/bin/env bash
set -euo pipefail

log() { printf '%s\n' "$*"; }
ok() { printf '✅ %s\n' "$*"; }
warn() { printf '⚠️ %s\n' "$*"; }
err() { printf '❌ %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

is_active() {
  local unit="$1"
  systemctl is-active --quiet "$unit" 2>/dev/null
}

is_enabled() {
  systemctl is-enabled --quiet "$1" 2>/dev/null
}
