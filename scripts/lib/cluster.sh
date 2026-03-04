#!/usr/bin/env bash
set -euo pipefail

normalize_role() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | xargs
}

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
  local master_host="$3"
  local master_port="$4"
  local master_user="$5"
  local master_key="$6"
  local master_nodes_path="$7"

  if [ -z "$master_host" ]; then
    echo "ℹ️ 未提供 MASTER_HOST，跳过自动注册到主控机"
    return 0
  fi

  if [ -z "$worker_ip" ]; then
    echo "⚠️ 无法获取 worker IP，跳过自动注册（可手动写入主控 nodes.json）"
    return 0
  fi

  local ssh_cmd=(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -p "$master_port")
  if [ -n "$master_key" ]; then
    ssh_cmd+=( -i "$master_key" )
  fi
  ssh_cmd+=("${master_user}@${master_host}")

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

  if NODES_PATH="$master_nodes_path" NODE_NAME="$worker_name" NODE_HOST="$worker_ip" NODE_PORT="22" NODE_USER="root" NODE_KEY="/root/.ssh/id_ed25519" \
     "${ssh_cmd[@]}" "python3 - <<'PY'
$remote_py
PY" >/tmp/traffic-register.out 2>/tmp/traffic-register.err; then
    echo "✅ 已自动注册到主控机 nodes.json: ${worker_name} -> ${worker_ip}"
    "${ssh_cmd[@]}" "systemctl restart traffic-local-bot.service" >/dev/null 2>&1 || true
  else
    echo "⚠️ 自动注册失败（不影响本机安装）"
    echo "--- stderr ---"
    cat /tmp/traffic-register.err || true
    echo "可手动在主控机追加："
    echo "{\"name\":\"${worker_name}\",\"host\":\"${worker_ip}\",\"port\":22,\"user\":\"root\",\"key\":\"/root/.ssh/id_ed25519\"}"
  fi
}
