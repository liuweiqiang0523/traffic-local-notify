#!/usr/bin/env bash
set -euo pipefail

CFG="/opt/traffic-local/config.json"
REPORT="/opt/traffic-local/report.py"
BOT_UNIT="traffic-local-bot.service"
TIMER_UNIT="traffic-local-report.timer"
NODES="/opt/traffic-local/nodes.json"
TOKEN_FILE="/opt/traffic-local/tg_bot_token.txt"
BASE_DIR="/opt/traffic-local"

ok() { echo "✅ $*"; }
warn() { echo "⚠️ $*"; }
err() { echo "❌ $*"; }

usage() {
  cat <<'EOF'
trafficctl - traffic-local-notify helper

Usage:
  trafficctl doctor
  trafficctl fix [all|perms|vnstat|timer|bot]
  trafficctl status
  trafficctl report
  trafficctl send
  trafficctl restart bot
  trafficctl restart timer
  trafficctl logs bot [N]

Examples:
  trafficctl doctor
  trafficctl fix all
  trafficctl restart bot
  trafficctl logs bot 100
EOF
}

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    err "需要 root 权限"
    exit 1
  fi
}

json_get() {
  local expr="$1"
  python3 - "$CFG" "$expr" <<'PY'
import json,sys
p,expr=sys.argv[1],sys.argv[2]
try:
  data=json.load(open(p,'r',encoding='utf-8'))
except Exception:
  print("")
  raise SystemExit(0)
cur=data
for k in expr.split('.'):
  if not k:
    continue
  if isinstance(cur,dict):
    cur=cur.get(k)
  else:
    cur=None
if cur is None:
  print("")
elif isinstance(cur,(dict,list)):
  print(json.dumps(cur,ensure_ascii=False))
else:
  print(cur)
PY
}

validate_nodes_schema() {
  [ -f "$NODES" ] || return 0
  python3 - "$NODES" <<'PY'
import json,sys
p=sys.argv[1]
try:
  nodes=json.load(open(p,'r',encoding='utf-8'))
except Exception as e:
  print(f"E: nodes.json 非法 JSON: {e}")
  raise SystemExit(2)
if not isinstance(nodes,list):
  print("E: nodes.json 必须是数组")
  raise SystemExit(2)
need=['name','host','port','user','key']
seen=set()
bad=0
for i,n in enumerate(nodes):
  if not isinstance(n,dict):
    print(f"E: 第{i+1}项不是对象")
    bad+=1
    continue
  miss=[k for k in need if k not in n]
  if miss:
    print(f"E: 第{i+1}项缺少字段: {','.join(miss)}")
    bad+=1
  name=str(n.get('name','')).strip().lower()
  if name in seen and name:
    print(f"E: 节点名重复: {n.get('name')}")
    bad+=1
  seen.add(name)
if bad:
  raise SystemExit(2)
print(f"OK:{len(nodes)}")
PY
}

check_ssh_to_nodes() {
  [ -f "$NODES" ] || return 0
  python3 - "$NODES" <<'PY' | while IFS='|' read -r name host port user key; do
import json,sys
nodes=json.load(open(sys.argv[1],'r',encoding='utf-8'))
for n in nodes:
  print(f"{n.get('name','')}|{n.get('host','')}|{n.get('port',22)}|{n.get('user','root')}|{n.get('key','')}")
PY
    [ -n "$host" ] || { warn "[$name] 缺少 host，跳过 SSH 测试"; continue; }
    local_cmd=(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -p "$port")
    [ -n "$key" ] && local_cmd+=( -i "$key" )
    if "${local_cmd[@]}" "${user}@${host}" "echo ok" >/dev/null 2>&1; then
      ok "[$name] SSH 连通正常"
    else
      warn "[$name] SSH 连通失败（检查 key/防火墙/22端口）"
    fi
  done
}

cmd_doctor() {
  local fail=0
  echo "== traffic-local doctor =="

  if [ -f "$REPORT" ]; then ok "report.py 存在"; else err "缺少 $REPORT"; fail=1; fi
  if [ -f "$CFG" ]; then ok "config.json 存在"; else err "缺少 $CFG"; fail=1; fi
  if [ -f "$TOKEN_FILE" ]; then ok "token 文件存在"; else err "缺少 token 文件"; fail=1; fi

  if command -v vnstat >/dev/null 2>&1; then ok "vnstat 已安装"; else err "vnstat 未安装"; fail=1; fi
  if systemctl is-active --quiet vnstat 2>/dev/null; then ok "vnstat 服务运行中"; else warn "vnstat 服务未运行"; fi

  if systemctl is-enabled --quiet "$TIMER_UNIT" 2>/dev/null; then ok "timer 已启用"; else warn "timer 未启用（若用 cron 可忽略）"; fi
  if systemctl is-active --quiet "$TIMER_UNIT" 2>/dev/null; then ok "timer 运行中"; else warn "timer 未运行（若用 cron 可忽略）"; fi

  if systemctl is-enabled --quiet "$BOT_UNIT" 2>/dev/null; then ok "bot listener 已启用"; else warn "bot listener 未启用（worker 可忽略）"; fi
  if systemctl is-active --quiet "$BOT_UNIT" 2>/dev/null; then ok "bot listener 运行中"; else warn "bot listener 未运行（worker 可忽略）"; fi

  if [ -d "$BASE_DIR" ]; then
    local dperm
    dperm="$(stat -f '%Lp' "$BASE_DIR" 2>/dev/null || true)"
    [ "$dperm" = "700" ] && ok "/opt/traffic-local 权限安全(700)" || warn "/opt/traffic-local 建议权限 700（当前 $dperm）"
  fi

  if [ -f "$TOKEN_FILE" ]; then
    local tperm
    tperm="$(stat -f '%Lp' "$TOKEN_FILE" 2>/dev/null || true)"
    [ "$tperm" = "600" ] && ok "token 权限安全(600)" || warn "token 建议权限 600（当前 $tperm）"
  fi

  if [ -f "$CFG" ]; then
    if python3 -m json.tool "$CFG" >/dev/null 2>&1; then
      ok "config.json JSON 格式正常"
    else
      err "config.json JSON 格式错误"
      fail=1
    fi

    local allow_ids
    allow_ids="$(json_get allowed_user_ids)"
    if [ -n "$allow_ids" ] && [ "$allow_ids" != "[]" ]; then
      ok "已配置 allowed_user_ids（命令白名单）"
    else
      warn "未配置 allowed_user_ids，建议加白名单"
    fi
  fi

  if [ -f "$NODES" ]; then
    local out
    out="$(validate_nodes_schema 2>&1)" || {
      err "nodes.json 校验失败"
      echo "$out"
      fail=1
      out=""
    }
    [ -n "$out" ] && ok "nodes.json 校验通过（${out#OK:} 个节点）"

    if systemctl is-active --quiet "$BOT_UNIT" 2>/dev/null; then
      check_ssh_to_nodes
    fi
  else
    warn "nodes.json 不存在（master 才需要）"
  fi

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

fix_perms() {
  [ -d "$BASE_DIR" ] && chmod 700 "$BASE_DIR" && ok "已修复 $BASE_DIR 权限为 700"
  [ -f "$TOKEN_FILE" ] && chmod 600 "$TOKEN_FILE" && ok "已修复 token 权限为 600"
  [ -f "$CFG" ] && chmod 600 "$CFG" && ok "已修复 config 权限为 600"
  [ -f "$NODES" ] && chmod 600 "$NODES" && ok "已修复 nodes 权限为 600"
}

fix_service_vnstat() {
  systemctl enable --now vnstat >/dev/null 2>&1 || true
  if systemctl is-active --quiet vnstat 2>/dev/null; then
    ok "vnstat 已启用并运行"
  else
    warn "vnstat 启动失败，请手动检查"
  fi
}

fix_timer() {
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl enable --now "$TIMER_UNIT" >/dev/null 2>&1 || true
  if systemctl is-active --quiet "$TIMER_UNIT" 2>/dev/null; then
    ok "$TIMER_UNIT 已启用并运行"
  else
    warn "$TIMER_UNIT 启动失败（若你用 cron 可忽略）"
  fi
}

fix_bot() {
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl enable --now "$BOT_UNIT" >/dev/null 2>&1 || true
  if systemctl is-active --quiet "$BOT_UNIT" 2>/dev/null; then
    ok "$BOT_UNIT 已启用并运行"
  else
    warn "$BOT_UNIT 启动失败，请看日志：trafficctl logs bot 100"
  fi
}

cmd_fix() {
  need_root
  case "${1:-all}" in
    all)
      fix_perms
      fix_service_vnstat
      fix_timer
      fix_bot
      ;;
    perms) fix_perms ;;
    vnstat) fix_service_vnstat ;;
    timer) fix_timer ;;
    bot) fix_bot ;;
    *)
      err "用法: trafficctl fix [all|perms|vnstat|timer|bot]"
      exit 1
      ;;
  esac
}

cmd_status() {
  echo "== service status =="
  systemctl status vnstat --no-pager -n 0 || true
  echo
  systemctl status "$TIMER_UNIT" --no-pager -n 0 || true
  echo
  systemctl status "$BOT_UNIT" --no-pager -n 0 || true
}

cmd_report() { python3 "$REPORT" --dry-run; }
cmd_send() { python3 "$REPORT" --send; }

cmd_restart() {
  need_root
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
    fix) shift; cmd_fix "$@" ;;
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
