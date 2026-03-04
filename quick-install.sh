#!/usr/bin/env bash
set -euo pipefail

# Interactive one-command installer for both master and worker.
# Supports --defaults mode (ask minimum inputs).

if [ "$(id -u)" -ne 0 ]; then
  echo "请用 root 运行"
  exit 1
fi

DEFAULTS=false
MENU=false
for arg in "$@"; do
  case "$arg" in
    --defaults) DEFAULTS=true ;;
    --menu) MENU=true ;;
    -h|--help)
      cat <<'EOF'
用法：
  bash <(curl -fsSL .../quick-install.sh)
  bash <(curl -fsSL .../quick-install.sh) --defaults
  bash <(curl -fsSL .../quick-install.sh) --menu

--defaults: 极速模式，只问最少字段（角色/chat_id/token），其余走默认。
--menu: 菜单模式（安装后可直接跑 doctor）。
EOF
      exit 0
      ;;
  esac
done


if [ "$MENU" = "true" ] && [ -t 0 ]; then
  echo "请选择："
  echo "  1) 安装/初始化"
  echo "  2) 仅诊断（doctor）"
  read -r -p "输入 [1/2] (默认 1): " _pick
  _pick="${_pick:-1}"
  if [ "$_pick" = "2" ]; then
    if command -v trafficctl >/dev/null 2>&1; then
      exec trafficctl doctor
    elif [ -x /opt/traffic-local/trafficctl.sh ]; then
      exec /opt/traffic-local/trafficctl.sh doctor
    else
      echo "未发现 trafficctl，先安装后再诊断。"
      exit 1
    fi
  fi
fi

read -r -p "角色 [master/worker] (默认 worker): " ROLE
ROLE="${ROLE:-worker}"
ROLE="$(printf '%s' "$ROLE" | tr '[:upper:]' '[:lower:]' | xargs)"
if [ "$ROLE" != "master" ] && [ "$ROLE" != "worker" ]; then
  echo "角色必须是 master 或 worker"
  exit 1
fi

default_name="$(hostname)-$ROLE"
if [ "$DEFAULTS" = "true" ]; then
  SERVER_NAME="$default_name"
  LIMIT_GB="25600"
  SCHEDULE_MODE="cron"
  MASTER_USER="root"
  MASTER_KEY="/root/.ssh/id_ed25519"
else
  read -r -p "SERVER_NAME [${default_name}]: " SERVER_NAME
  SERVER_NAME="${SERVER_NAME:-$default_name}"

  read -r -p "LIMIT_GB [25600]: " LIMIT_GB
  LIMIT_GB="${LIMIT_GB:-25600}"

  read -r -p "SCHEDULE_MODE [cron/systemd] (默认 cron): " SCHEDULE_MODE
  SCHEDULE_MODE="${SCHEDULE_MODE:-cron}"

  MASTER_USER="root"
  MASTER_KEY="/root/.ssh/id_ed25519"
fi

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

MASTER_HOST=""
if [ "$ROLE" = "worker" ]; then
  read -r -p "MASTER_HOST (用于自动注册，可留空跳过): " MASTER_HOST
  if [ -n "$MASTER_HOST" ] && [ "$DEFAULTS" = "false" ]; then
    read -r -p "MASTER_USER [root]: " MASTER_USER
    MASTER_USER="${MASTER_USER:-root}"
    read -r -p "MASTER_KEY [/root/.ssh/id_ed25519]: " MASTER_KEY
    MASTER_KEY="${MASTER_KEY:-/root/.ssh/id_ed25519}"
  fi
fi

echo
echo "即将执行安装..."
printf 'ROLE=%s SERVER_NAME=%s LIMIT_GB=%s SCHEDULE_MODE=%s\n' "$ROLE" "$SERVER_NAME" "$LIMIT_GB" "$SCHEDULE_MODE"
if [ -n "$MASTER_HOST" ]; then
  printf 'MASTER_HOST=%s MASTER_USER=%s MASTER_KEY=%s\n' "$MASTER_HOST" "$MASTER_USER" "$MASTER_KEY"
fi
echo

export ROLE SERVER_NAME LIMIT_GB CHAT_ID BOT_TOKEN SCHEDULE_MODE MASTER_HOST MASTER_USER MASTER_KEY
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
