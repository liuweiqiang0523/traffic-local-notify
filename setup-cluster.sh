#!/usr/bin/env bash
set -euo pipefail

# One-shot cluster bootstrap helper for traffic-local-notify
# Goal: one command per node, with optional worker auto-register to master nodes.json

ROLE="${ROLE:-worker}" # master|worker
SERVER_NAME="${SERVER_NAME:-}"
LIMIT_GB="${LIMIT_GB:-}"
CHAT_ID="${CHAT_ID:-}"
BOT_TOKEN="${BOT_TOKEN:-}"
IFACE="${IFACE:-auto}"
BILLING_DAY="${BILLING_DAY:-27}"
BILLING_HMS="${BILLING_HMS:-00:02:06}"
SCHEDULE_MODE="${SCHEDULE_MODE:-cron}"

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

ROLE="$(printf '%s' "$ROLE" | tr '[:upper:]' '[:lower:]' | xargs)"
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

detect_public_ip() {
  local ip=""
  ip="$(curl -4fsSL --max-time 8 https://api.ipify.org 2>/dev/null || true)"
  [ -n "$ip" ] || ip="$(curl -4fsSL --max-time 8 https://ifconfig.me 2>/dev/null || true)"
  [ -n "$ip" ] || ip="$(curl -4fsSL --max-time 8 https://ipinfo.io/ip 2>/dev/null || true)"
  printf '%s' "$ip"
}

register_worker_to_master() {
  local worker_name="$1"
  local worker_ip="$2"

  if [ -z "$MASTER_HOST" ]; then
    echo "ℹ️ 未提供 MASTER_HOST，跳过自动注册到主控机"
    return 0
  fi

  if [ -z "$worker_ip" ]; then
    echo "⚠️ 无法获取 worker IP，跳过自动注册（可手动写入主控 nodes.json）"
    return 0
  fi

  local ssh_cmd=(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -p "$MASTER_PORT")
  if [ -n "$MASTER_KEY" ]; then
    ssh_cmd+=( -i "$MASTER_KEY" )
  fi
  ssh_cmd+=("${MASTER_USER}@${MASTER_HOST}")

  local remote_py
  read -r -d '' remote_py <<'PY' || true
import json, os
path = os.environ.get("NODES_PATH", "/opt/traffic-local/nodes.json")
name = os.environ["NODE_NAME"]
host = os.environ["NODE_HOST"]
port = int(os.environ.get("NODE_PORT", "22"))
user = os.environ.get("NODE_USER", "root")
key = os.environ.get("NODE_KEY", "/root/.ssh/id_ed25519")

nodes = []
if os.path.exists(path):
    try:
        nodes = json.load(open(path, "r", encoding="utf-8"))
    except Exception:
        nodes = []
if not isinstance(nodes, list):
    nodes = []

new_item = {"name": name, "host": host, "port": port, "user": user, "key": key}
updated = False
for i, n in enumerate(nodes):
    if str(n.get("name", "")).lower() == name.lower():
        nodes[i] = new_item
        updated = True
        break
if not updated:
    nodes.append(new_item)

json.dump(nodes, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(f"UPDATED:{name}@{host}")
PY

  if NODES_PATH="$MASTER_NODES_PATH" NODE_NAME="$worker_name" NODE_HOST="$worker_ip" NODE_PORT="22" NODE_USER="root" NODE_KEY="/root/.ssh/id_ed25519" \
     "${ssh_cmd[@]}" "python3 - <<'PY'
$remote_py
PY" >/tmp/traffic-register.out 2>/tmp/traffic-register.err; then
    echo "✅ 已自动注册到主控机 nodes.json: ${worker_name} -> ${worker_ip}"
    # best-effort restart listener
    "${ssh_cmd[@]}" "systemctl restart traffic-local-bot.service" >/dev/null 2>&1 || true
  else
    echo "⚠️ 自动注册失败（不影响本机安装）"
    echo "--- stderr ---"
    cat /tmp/traffic-register.err || true
    echo "可手动在主控机追加："
    echo "{\"name\":\"${worker_name}\",\"host\":\"${worker_ip}\",\"port\":22,\"user\":\"root\",\"key\":\"/root/.ssh/id_ed25519\"}"
  fi
}

DEPLOY_ROLE="$ROLE" INIT=true \
SERVER_NAME="$SERVER_NAME" LIMIT_GB="$LIMIT_GB" CHAT_ID="$CHAT_ID" BOT_TOKEN="$BOT_TOKEN" \
IFACE="$IFACE" BILLING_DAY="$BILLING_DAY" BILLING_HMS="$BILLING_HMS" SCHEDULE_MODE="$SCHEDULE_MODE" \
NODES_JSON_B64="$NODES_JSON_B64" NODES_JSON_URL="$NODES_JSON_URL" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)

python3 /opt/traffic-local/report.py --self-check || true

echo
if [ "$ROLE" = "master" ]; then
  echo "✅ 主控机完成。"
  echo "Telegram 测试：/nodes  /traffic <node>  /selfcheck <node>"
else
  if [ -z "$NODE_IP" ] && [ "$AUTO_DETECT_IP" = "true" ]; then
    NODE_IP="$(detect_public_ip)"
  fi
  register_worker_to_master "$SERVER_NAME" "$NODE_IP"
  echo "✅ worker 完成。"
fi
