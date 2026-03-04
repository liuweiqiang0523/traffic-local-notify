#!/usr/bin/env bash
set -euo pipefail

# One-shot cluster bootstrap helper for traffic-local-notify
# Usage examples:
#   # master
#   ROLE=master SERVER_NAME=master-hub LIMIT_GB=25600 CHAT_ID=-100xxxx BOT_TOKEN=123:abc ./setup-cluster.sh
#   # worker
#   ROLE=worker SERVER_NAME=lax-01 LIMIT_GB=25600 CHAT_ID=-100xxxx BOT_TOKEN=123:abc ./setup-cluster.sh

ROLE="${ROLE:-worker}" # master|worker
SERVER_NAME="${SERVER_NAME:-}"
LIMIT_GB="${LIMIT_GB:-}"
CHAT_ID="${CHAT_ID:-}"
BOT_TOKEN="${BOT_TOKEN:-}"
IFACE="${IFACE:-auto}"
BILLING_DAY="${BILLING_DAY:-27}"
BILLING_HMS="${BILLING_HMS:-00:02:06}"
SCHEDULE_MODE="${SCHEDULE_MODE:-cron}"
NODES_JSON_B64="${NODES_JSON_B64:-}"
NODES_JSON_URL="${NODES_JSON_URL:-}"

if [ -z "$SERVER_NAME" ]; then
  SERVER_NAME="$(hostname)-${ROLE}"
fi

if [ -z "$SERVER_NAME" ] || [ -z "$LIMIT_GB" ] || [ -z "$CHAT_ID" ] || [ -z "$BOT_TOKEN" ]; then
  echo "缺少参数：SERVER_NAME LIMIT_GB CHAT_ID BOT_TOKEN"
  exit 1
fi

DEPLOY_ROLE="$ROLE" INIT=true \
SERVER_NAME="$SERVER_NAME" LIMIT_GB="$LIMIT_GB" CHAT_ID="$CHAT_ID" BOT_TOKEN="$BOT_TOKEN" \
IFACE="$IFACE" BILLING_DAY="$BILLING_DAY" BILLING_HMS="$BILLING_HMS" SCHEDULE_MODE="$SCHEDULE_MODE" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)

python3 /opt/traffic-local/report.py --self-check || true

echo
echo "完成。"
if [ "$ROLE" = "master" ]; then
  echo "下一步：编辑 /opt/traffic-local/nodes.json 并确保 SSH 免密。"
  echo "测试：/nodes, /traffic <node>, /selfcheck <node>"
else
  echo "worker 已部署，定时上报正常即可。"
fi


# optional: auto provision nodes.json on master
if [ "$ROLE" = "master" ]; then
  if [ -n "$NODES_JSON_B64" ]; then
    printf "%s" "$NODES_JSON_B64" | base64 -d > /opt/traffic-local/nodes.json
    chmod 600 /opt/traffic-local/nodes.json
    systemctl restart traffic-local-bot.service || true
    echo "✅ 已通过 NODES_JSON_B64 写入 /opt/traffic-local/nodes.json"
  elif [ -n "$NODES_JSON_URL" ]; then
    curl -fsSL "$NODES_JSON_URL" -o /opt/traffic-local/nodes.json
    chmod 600 /opt/traffic-local/nodes.json
    systemctl restart traffic-local-bot.service || true
    echo "✅ 已通过 NODES_JSON_URL 写入 /opt/traffic-local/nodes.json"
  fi
fi
