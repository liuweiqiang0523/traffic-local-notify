#!/usr/bin/env bash
set -euo pipefail

CFG="/opt/traffic-local/config.json"
REPORT="/opt/traffic-local/report.py"
BOT_UNIT="traffic-local-bot.service"
TIMER_UNIT="traffic-local-report.timer"
SERVICE_UNIT="traffic-local-report.service"
NODES="/opt/traffic-local/nodes.json"

ok() { echo "✅ $*"; }
warn() { echo "⚠️ $*"; }
err() { echo "❌ $*"; }

usage() {
  cat <<'EOF'
trafficctl - traffic-local-notify helper

Usage:
  trafficctl doctor
  trafficctl status
  trafficctl report
  trafficctl send
  trafficctl restart bot
  trafficctl restart timer
  trafficctl logs bot [N]

Examples:
  trafficctl doctor
  trafficctl restart bot
  trafficctl logs bot 100
EOF
}

need_root_for_restart() {
  if [ "$(id -u)" -ne 0 ]; then
    err "需要 root 权限"
    exit 1
  fi
}

cmd_doctor() {
  local fail=0
  echo "== traffic-local doctor =="

  if [ -f "$REPORT" ]; then ok "report.py 存在"; else err "缺少 $REPORT"; fail=1; fi
  if [ -f "$CFG" ]; then ok "config.json 存在"; else err "缺少 $CFG"; fail=1; fi
  if [ -f "/opt/traffic-local/tg_bot_token.txt" ]; then ok "token 文件存在"; else err "缺少 token 文件"; fail=1; fi

  if command -v vnstat >/dev/null 2>&1; then ok "vnstat 已安装"; else err "vnstat 未安装"; fail=1; fi

  if systemctl is-active --quiet vnstat 2>/dev/null; then ok "vnstat 服务运行中"; else warn "vnstat 服务未运行"; fi

  if systemctl is-enabled --quiet "$TIMER_UNIT" 2>/dev/null; then ok "timer 已启用"; else warn "timer 未启用（若用 cron 可忽略）"; fi
  if systemctl is-active --quiet "$TIMER_UNIT" 2>/dev/null; then ok "timer 运行中"; else warn "timer 未运行（若用 cron 可忽略）"; fi

  if systemctl is-enabled --quiet "$BOT_UNIT" 2>/dev/null; then ok "bot listener 已启用"; else warn "bot listener 未启用（worker 可忽略）"; fi
  if systemctl is-active --quiet "$BOT_UNIT" 2>/dev/null; then ok "bot listener 运行中"; else warn "bot listener 未运行（worker 可忽略）"; fi

  if [ -f "$NODES" ]; then ok "nodes.json 存在"; else warn "nodes.json 不存在（master 才需要）"; fi

  if [ -f "$REPORT" ]; then
    echo
    python3 "$REPORT" --self-check || true
  fi

  echo
  if [ "$fail" -eq 0 ]; then
    ok "基础检查完成"
  else
    err "存在关键问题，请先修复后再试"
    exit 1
  fi
}

cmd_status() {
  echo "== service status =="
  systemctl status vnstat --no-pager -n 0 || true
  echo
  systemctl status "$TIMER_UNIT" --no-pager -n 0 || true
  echo
  systemctl status "$BOT_UNIT" --no-pager -n 0 || true
}

cmd_report() {
  python3 "$REPORT" --dry-run
}

cmd_send() {
  python3 "$REPORT" --send
}

cmd_restart() {
  need_root_for_restart
  case "${1:-}" in
    bot)
      systemctl restart "$BOT_UNIT"
      ok "已重启 $BOT_UNIT"
      ;;
    timer)
      systemctl restart "$TIMER_UNIT"
      ok "已重启 $TIMER_UNIT"
      ;;
    *)
      err "用法: trafficctl restart [bot|timer]"
      exit 1
      ;;
  esac
}

cmd_logs() {
  case "${1:-}" in
    bot)
      local n="${2:-80}"
      journalctl -u "$BOT_UNIT" -n "$n" --no-pager
      ;;
    *)
      err "用法: trafficctl logs bot [N]"
      exit 1
      ;;
  esac
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    doctor) cmd_doctor ;;
    status) cmd_status ;;
    report) cmd_report ;;
    send) cmd_send ;;
    restart) shift; cmd_restart "$@" ;;
    logs) shift; cmd_logs "$@" ;;
    -h|--help|help|"") usage ;;
    *) err "未知命令: $cmd"; usage; exit 1 ;;
  esac
}

main "$@"
