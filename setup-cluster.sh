#!/usr/bin/env bash
set -euo pipefail

# One-shot cluster bootstrap helper for traffic-local-notify
# Goal: one command per node, with optional worker auto-register to master nodes.json

REPO_OWNER="${REPO_OWNER:-liuweiqiang0523}"
REPO_NAME="${REPO_NAME:-traffic-local-notify}"
BRANCH="${BRANCH:-main}"
VERSION="${VERSION:-}"
REF="${VERSION:-$BRANCH}"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REF}"

ROLE="${ROLE:-worker}" # master|worker
SERVER_NAME="${SERVER_NAME:-}"
LIMIT_GB="${LIMIT_GB:-}"
CHAT_ID="${CHAT_ID:-}"
BOT_TOKEN="${BOT_TOKEN:-}"
IFACE="${IFACE:-auto}"
BILLING_DAY="${BILLING_DAY:-$(date +%-d)}"
BILLING_HMS="${BILLING_HMS:-$(date +%H:%M:%S)}"
SCHEDULE_MODE="${SCHEDULE_MODE:-cron}"
ALLOWED_USER_IDS="${ALLOWED_USER_IDS:-}"

# optional master node list payload when ROLE=master
NODES_JSON_B64="${NODES_JSON_B64:-}"
NODES_JSON_URL="${NODES_JSON_URL:-}"

# optional worker auto-register to master
MASTER_HOST="${MASTER_HOST:-}"
MASTER_PORT="${MASTER_PORT:-22}"
MASTER_USER="${MASTER_USER:-root}"
MASTER_KEY="${MASTER_KEY:-}"                 # path to SSH private key on worker
MASTER_NODES_PATH="${MASTER_NODES_PATH:-/opt/traffic-local/nodes.json}"
NODE_IP="${NODE_IP:-}"                       # optional manual override
AUTO_DETECT_IP="${AUTO_DETECT_IP:-true}"    # true|false

# ---- load cluster helpers ----
if [ -f "$(dirname "$0")/scripts/lib/cluster.sh" ]; then
  # local repo mode
  # shellcheck source=/dev/null
  source "$(dirname "$0")/scripts/lib/cluster.sh"
else
  # one-file curl mode
  # shellcheck source=/dev/null
  source <(curl -fsSL "${RAW_BASE}/scripts/lib/cluster.sh")
fi

ROLE="$(normalize_role "$ROLE")"
if [ "$ROLE" != "master" ] && [ "$ROLE" != "worker" ]; then
  echo "ROLE 必须是 master 或 worker"
  exit 1
fi

if [ -z "$SERVER_NAME" ]; then
  SERVER_NAME="$(hostname)-${ROLE}"
fi

if [ -z "$LIMIT_GB" ] || [ -z "$CHAT_ID" ] || [ -z "$BOT_TOKEN" ]; then
  echo "缺少参数：LIMIT_GB CHAT_ID BOT_TOKEN（SERVER_NAME 可省略自动生成）"
  exit 1
fi

DEPLOY_ROLE="$ROLE" INIT=true \
SERVER_NAME="$SERVER_NAME" LIMIT_GB="$LIMIT_GB" CHAT_ID="$CHAT_ID" BOT_TOKEN="$BOT_TOKEN" \
IFACE="$IFACE" BILLING_DAY="$BILLING_DAY" BILLING_HMS="$BILLING_HMS" SCHEDULE_MODE="$SCHEDULE_MODE" \
ALLOWED_USER_IDS="$ALLOWED_USER_IDS" \
NODES_JSON_B64="$NODES_JSON_B64" NODES_JSON_URL="$NODES_JSON_URL" \
bash <(curl -fsSL "${RAW_BASE}/install.sh")

python3 /opt/traffic-local/report.py --self-check || true

echo
if [ "$ROLE" = "master" ]; then
  echo "✅ 主控机完成。"
  echo "Telegram 测试：/nodes  /summary  /traffic <node>  /selfcheck <node>"
else
  if [ -z "$NODE_IP" ] && [ "$AUTO_DETECT_IP" = "true" ]; then
    NODE_IP="$(detect_public_ip)"
  fi
  register_worker_to_master "$SERVER_NAME" "$NODE_IP" "$MASTER_HOST" "$MASTER_PORT" "$MASTER_USER" "$MASTER_KEY" "$MASTER_NODES_PATH"
  echo "✅ worker 完成。"
fi
