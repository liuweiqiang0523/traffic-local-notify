#!/usr/bin/env bash
set -euo pipefail

echo "== traffic-local-notify installer =="

if [ "$(id -u)" -ne 0 ]; then
  echo "请用 root 运行"
  exit 1
fi

REPO_OWNER="${REPO_OWNER:-liuweiqiang0523}"
REPO_NAME="${REPO_NAME:-traffic-local-notify}"
BRANCH="${BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}"

# install modes
ENABLE_SYSTEMD_TIMER="${ENABLE_SYSTEMD_TIMER:-false}" # true/false
INIT="${INIT:-false}"                                 # true/false
SCHEDULE_MODE="${SCHEDULE_MODE:-}"                    # cron/systemd/none

need_cmd() { command -v "$1" >/dev/null 2>&1; }

download_file() {
  local url="$1" out="$2"
  if need_cmd curl; then
    curl -fsSL "$url" -o "$out"
  elif need_cmd wget; then
    wget -qO "$out" "$url"
  else
    echo "缺少 curl/wget，正在安装 curl..."
    apt-get update && apt-get install -y curl
    curl -fsSL "$url" -o "$out"
  fi
}

detect_iface() {
  if command -v ip >/dev/null 2>&1; then
    ip -o -4 route show to default 2>/dev/null | awk '{print $5}' | head -n1
  fi
}

setup_cron() {
  ( crontab -l 2>/dev/null | grep -v '/opt/traffic-local/report.py' ; \
    echo '55 23 * * * /usr/bin/python3 /opt/traffic-local/report.py --send >> /opt/traffic-local/run.log 2>&1' ) | crontab -
  echo "✅ 已配置 cron：每天 23:55 推送"
}

setup_systemd_timer() {
  local local_service="$1" local_timer="$2"

  if [ -f "$local_service" ] && [ -f "$local_timer" ]; then
    install -m 644 "$local_service" /etc/systemd/system/traffic-local-report.service
    install -m 644 "$local_timer" /etc/systemd/system/traffic-local-report.timer
  else
    download_file "${RAW_BASE}/systemd/traffic-local-report.service" "/etc/systemd/system/traffic-local-report.service"
    download_file "${RAW_BASE}/systemd/traffic-local-report.timer" "/etc/systemd/system/traffic-local-report.timer"
  fi

  # 清理 cron 旧任务
  crontab -l 2>/dev/null | grep -v '/opt/traffic-local/report.py' | crontab - || true

  systemctl daemon-reload
  systemctl enable --now traffic-local-report.timer
  echo "✅ 已启用 systemd timer：traffic-local-report.timer"
}

write_config_interactive() {
  local default_iface="$(detect_iface)"
  [ -z "$default_iface" ] && default_iface="eth0"

  local server_name interface limit_gb billing_day billing_hms chat_id bot_token

  echo
  echo "=== 交互式初始化 ==="
  read -r -p "服务器名称 [$(hostname)]: " server_name
  server_name="${server_name:-$(hostname)}"

  read -r -p "网卡 [auto] (可填 auto 或 ${default_iface}): " interface
  interface="${interface:-auto}"

  read -r -p "月流量限额(GB) [25600]: " limit_gb
  limit_gb="${limit_gb:-25600}"

  read -r -p "账期日(1-28) [27]: " billing_day
  billing_day="${billing_day:-27}"

  read -r -p "账期时间(HH:MM:SS) [00:02:06]: " billing_hms
  billing_hms="${billing_hms:-00:02:06}"

  read -r -p "Telegram Chat ID (如 -100xxxx): " chat_id
  if [ -z "$chat_id" ]; then
    echo "❌ chat_id 不能为空"
    exit 1
  fi

  read -r -s -p "Telegram Bot Token: " bot_token
  echo
  if [ -z "$bot_token" ]; then
    echo "❌ bot token 不能为空"
    exit 1
  fi

  cat > /opt/traffic-local/config.json <<JSON
{
  "server_name": "${server_name}",
  "interface": "${interface}",
  "limit_gb": ${limit_gb},
  "billing_day": ${billing_day},
  "billing_hms": "${billing_hms}",
  "telegram_bot_token_file": "/opt/traffic-local/tg_bot_token.txt",
  "telegram_chat_id": "${chat_id}",
  "send_always": false,
  "alert_levels": [80, 90, 100]
}
JSON

  printf "%s\n" "$bot_token" > /opt/traffic-local/tg_bot_token.txt
  chmod 600 /opt/traffic-local/tg_bot_token.txt

  echo "✅ 已写入配置与 token"
}

apt-get update
apt-get install -y python3 vnstat
systemctl enable --now vnstat

mkdir -p /opt/traffic-local
chmod 700 /opt/traffic-local

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null || true)"
LOCAL_REPORT="${SCRIPT_DIR}/report.py"
LOCAL_CONFIG="${SCRIPT_DIR}/config.template.json"
LOCAL_SERVICE="${SCRIPT_DIR}/systemd/traffic-local-report.service"
LOCAL_TIMER="${SCRIPT_DIR}/systemd/traffic-local-report.timer"

# 支持两种安装方式：
# 1) git clone 后执行 ./install.sh（本地文件存在）
# 2) bash <(curl .../install.sh)（本地文件不存在，自动在线拉取）
if [ -n "$SCRIPT_DIR" ] && [ -f "$LOCAL_REPORT" ] && [ -f "$LOCAL_CONFIG" ]; then
  install -m 755 "$LOCAL_REPORT" /opt/traffic-local/report.py
  [ -f /opt/traffic-local/config.json ] || install -m 600 "$LOCAL_CONFIG" /opt/traffic-local/config.json
else
  echo "检测到单文件安装模式，正在从 GitHub 拉取 report.py 和 config.template.json..."
  download_file "${RAW_BASE}/report.py" "$TMPDIR/report.py"
  download_file "${RAW_BASE}/config.template.json" "$TMPDIR/config.template.json"
  install -m 755 "$TMPDIR/report.py" /opt/traffic-local/report.py
  [ -f /opt/traffic-local/config.json ] || install -m 600 "$TMPDIR/config.template.json" /opt/traffic-local/config.json
fi

if [ ! -f /opt/traffic-local/tg_bot_token.txt ]; then
  touch /opt/traffic-local/tg_bot_token.txt
  chmod 600 /opt/traffic-local/tg_bot_token.txt
fi

if ! grep -q "alias traffic='python3 /opt/traffic-local/report.py --dry-run'" /root/.bashrc 2>/dev/null; then
  cat >> /root/.bashrc <<'E2'
alias traffic='python3 /opt/traffic-local/report.py --dry-run'
alias traffic-send='python3 /opt/traffic-local/report.py --send'
E2
fi

if [ "$INIT" = "true" ]; then
  write_config_interactive

  echo
  echo "正在执行一次测试推送..."
  if python3 /opt/traffic-local/report.py --send; then
    echo "✅ 测试推送完成"
  else
    echo "❌ 测试推送失败，请检查配置后重试：python3 /opt/traffic-local/report.py --send"
    exit 1
  fi

  echo
  if [ -z "$SCHEDULE_MODE" ]; then
    if [ -t 0 ]; then
      read -r -p "选择定时方式 [cron/systemd/none] (默认 cron): " SCHEDULE_MODE || true
      SCHEDULE_MODE="${SCHEDULE_MODE:-cron}"
    else
      SCHEDULE_MODE="cron"
      echo "未检测到交互终端，默认使用 cron"
    fi
  fi

  SCHEDULE_MODE="$(printf '%s' "$SCHEDULE_MODE" | tr '[:upper:]' '[:lower:]' | xargs)"

  case "$SCHEDULE_MODE" in
    cron)
      setup_cron
      ;;
    systemd)
      setup_systemd_timer "$LOCAL_SERVICE" "$LOCAL_TIMER"
      ;;
    none)
      echo "已跳过定时配置"
      ;;
    *)
      echo "未知定时方式：$SCHEDULE_MODE，跳过"
      ;;
  esac

elif [ "$ENABLE_SYSTEMD_TIMER" = "true" ]; then
  setup_systemd_timer "$LOCAL_SERVICE" "$LOCAL_TIMER"
fi

echo
echo "安装完成。"
echo "常用命令："
echo "  python3 /opt/traffic-local/report.py --dry-run"
echo "  python3 /opt/traffic-local/report.py --send"
echo
cat <<'CRON_HINT'
若你要手动使用 cron（23:55）：
  ( crontab -l 2>/dev/null | grep -v '/opt/traffic-local/report.py' ; \
    echo '55 23 * * * /usr/bin/python3 /opt/traffic-local/report.py --send >> /opt/traffic-local/run.log 2>&1' ) | crontab -
CRON_HINT
