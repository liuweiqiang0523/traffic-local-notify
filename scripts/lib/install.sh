#!/usr/bin/env bash
set -euo pipefail

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

normalize_user_ids() {
  local input="$1"
  if [ -z "$input" ]; then
    echo ""
    return 0
  fi
  printf '%s' "$input" | tr ',' '\n' | sed '/^$/d' | sed 's/[^0-9]//g' | awk 'NF{printf "%s%s", sep, $1; sep=","}'
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

  crontab -l 2>/dev/null | grep -v '/opt/traffic-local/report.py' | crontab - || true

  systemctl daemon-reload
  systemctl enable --now traffic-local-report.timer
  echo "✅ 已启用 systemd timer：traffic-local-report.timer"
}

setup_bot_listener() {
  if [ -f "$LOCAL_BOT_SERVICE" ]; then
    install -m 644 "$LOCAL_BOT_SERVICE" /etc/systemd/system/traffic-local-bot.service
  else
    download_file "${RAW_BASE}/systemd/traffic-local-bot.service" "/etc/systemd/system/traffic-local-bot.service"
  fi

  systemctl daemon-reload
  systemctl enable --now traffic-local-bot.service
  echo "✅ 已启用 Telegram 命令监听：traffic-local-bot.service"
  echo "   节点清单文件：/opt/traffic-local/nodes.json"
}

write_config_from_env() {
  if [ -z "$SERVER_NAME" ] || [ -z "$LIMIT_GB" ] || [ -z "$CHAT_ID" ] || [ -z "$BOT_TOKEN" ]; then
    echo "❌ 环境变量模式缺少必要参数（需要 SERVER_NAME/LIMIT_GB/CHAT_ID/BOT_TOKEN）"
    exit 1
  fi

  local allowed_json
  allowed_json="$(normalize_user_ids "$ALLOWED_USER_IDS")"

  cat > /opt/traffic-local/config.json <<JSON
{
  "server_name": "${SERVER_NAME}",
  "interface": "${IFACE}",
  "limit_gb": ${LIMIT_GB},
  "billing_day": ${BILLING_DAY},
  "billing_hms": "${BILLING_HMS}",
  "telegram_bot_token_file": "/opt/traffic-local/tg_bot_token.txt",
  "telegram_chat_id": "${CHAT_ID}",
  "send_always": false,
  "alert_levels": [80, 90, 100],
  "allowed_user_ids": [${allowed_json}]
}
JSON

  printf "%s\n" "$BOT_TOKEN" > /opt/traffic-local/tg_bot_token.txt
  chmod 600 /opt/traffic-local/tg_bot_token.txt

  echo "✅ 已按环境变量写入配置与 token"
}

write_config_interactive() {
  local default_iface="$(detect_iface)"
  [ -z "$default_iface" ] && default_iface="eth0"

  local server_name interface limit_gb billing_day billing_hms chat_id bot_token allow_ids allowed_json

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

  read -r -p "允许操作的 Telegram user_id（逗号分隔，可留空不限制）: " allow_ids
  allowed_json="$(normalize_user_ids "$allow_ids")"

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
  "alert_levels": [80, 90, 100],
  "allowed_user_ids": [${allowed_json}]
}
JSON

  printf "%s\n" "$bot_token" > /opt/traffic-local/tg_bot_token.txt
  chmod 600 /opt/traffic-local/tg_bot_token.txt

  echo "✅ 已写入配置与 token"
}

apply_nodes_payload_if_any() {
  # optional: allow master to inject nodes list during one-liner install
  local role="$(printf '%s' "$DEPLOY_ROLE" | tr '[:upper:]' '[:lower:]' | xargs)"
  [ "$role" = "master" ] || return 0

  if [ -n "${NODES_JSON_B64:-}" ]; then
    if printf '%s' "$NODES_JSON_B64" | base64 -d >/opt/traffic-local/nodes.json 2>/dev/null; then
      chmod 600 /opt/traffic-local/nodes.json
      echo "✅ 已应用 NODES_JSON_B64 到 /opt/traffic-local/nodes.json"
      return 0
    else
      echo "⚠️ NODES_JSON_B64 解码失败，保持原 nodes.json"
    fi
  fi

  if [ -n "${NODES_JSON_URL:-}" ]; then
    if download_file "$NODES_JSON_URL" /opt/traffic-local/nodes.json; then
      chmod 600 /opt/traffic-local/nodes.json
      echo "✅ 已从 NODES_JSON_URL 拉取 nodes.json"
      return 0
    else
      echo "⚠️ NODES_JSON_URL 拉取失败，保持原 nodes.json"
    fi
  fi
}
