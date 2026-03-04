#!/usr/bin/env bash
set -euo pipefail

# Interactive one-command installer for both master and worker.

if [ "$(id -u)" -ne 0 ]; then
  echo "请用 root 运行"
  exit 1
fi

read -r -p "角色 [master/worker] (默认 worker): " ROLE
ROLE="${ROLE:-worker}"
ROLE="$(printf '%s' "$ROLE" | tr '[:upper:]' '[:lower:]' | xargs)"
if [ "$ROLE" != "master" ] && [ "$ROLE" != "worker" ]; then
  echo "角色必须是 master 或 worker"
  exit 1
fi

default_name="$(hostname)-$ROLE"
read -r -p "SERVER_NAME [${default_name}]: " SERVER_NAME
SERVER_NAME="${SERVER_NAME:-$default_name}"

read -r -p "LIMIT_GB [25600]: " LIMIT_GB
LIMIT_GB="${LIMIT_GB:-25600}"

read -r -p "CHAT_ID (如 -100xxxx): " CHAT_ID
if [ -z "$CHAT_ID" ]; then
  echo "CHAT_ID 不能为空"
  exit 1
fi

read -r -s -p "BOT_TOKEN: " BOT_TOKEN
echo
if [ -z "$BOT_TOKEN" ]; then
  echo "BOT_TOKEN 不能为空"
  exit 1
fi

read -r -p "SCHEDULE_MODE [cron/systemd] (默认 cron): " SCHEDULE_MODE
SCHEDULE_MODE="${SCHEDULE_MODE:-cron}"

MASTER_HOST=""
MASTER_USER="root"
MASTER_KEY="/root/.ssh/id_ed25519"
if [ "$ROLE" = "worker" ]; then
  read -r -p "MASTER_HOST (用于自动注册，可留空跳过): " MASTER_HOST
  if [ -n "$MASTER_HOST" ]; then
    read -r -p "MASTER_USER [root]: " MASTER_USER
    MASTER_USER="${MASTER_USER:-root}"
    read -r -p "MASTER_KEY [/root/.ssh/id_ed25519]: " MASTER_KEY
    MASTER_KEY="${MASTER_KEY:-/root/.ssh/id_ed25519}"
  fi
fi

echo
echo "即将执行交互安装..."
echo

export ROLE SERVER_NAME LIMIT_GB CHAT_ID BOT_TOKEN SCHEDULE_MODE MASTER_HOST MASTER_USER MASTER_KEY
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
