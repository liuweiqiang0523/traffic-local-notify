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
VERSION="${VERSION:-}" # e.g. v1.0.13; if set, download from tag instead of branch
REF="${VERSION:-$BRANCH}"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REF}"

# install modes
ENABLE_SYSTEMD_TIMER="${ENABLE_SYSTEMD_TIMER:-false}" # true/false
INIT="${INIT:-false}"                                 # true/false
SCHEDULE_MODE="${SCHEDULE_MODE:-}"                    # cron/systemd/none
ENABLE_BOT_LISTENER="${ENABLE_BOT_LISTENER:-false}"       # true/false

# non-interactive config via env (v1.0.6)
SERVER_NAME="${SERVER_NAME:-}"
IFACE="${IFACE:-auto}"
LIMIT_GB="${LIMIT_GB:-}"
BILLING_DAY="${BILLING_DAY:-$(date +%-d)}"
BILLING_HMS="${BILLING_HMS:-$(date +%H:%M:%S)}"
CHAT_ID="${CHAT_ID:-}"
BOT_TOKEN="${BOT_TOKEN:-}"
DEPLOY_ROLE="${DEPLOY_ROLE:-worker}" # master|worker
ALLOWED_USER_IDS="${ALLOWED_USER_IDS:-}" # comma-separated telegram user ids
NODES_JSON_B64="${NODES_JSON_B64:-}"
NODES_JSON_URL="${NODES_JSON_URL:-}"

# load shared installer helpers (local repo mode / curl mode)
if [ -f "$(dirname "$0")/scripts/lib/install.sh" ]; then
  # shellcheck source=/dev/null
  source "$(dirname "$0")/scripts/lib/install.sh"
else
  # shellcheck source=/dev/null
  source <(curl -fsSL "${RAW_BASE}/scripts/lib/install.sh")
fi
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
LOCAL_BOT="${SCRIPT_DIR}/bot_listener.py"
LOCAL_BOT_SERVICE="${SCRIPT_DIR}/systemd/traffic-local-bot.service"
LOCAL_NODES_EXAMPLE="${SCRIPT_DIR}/nodes.example.json"
LOCAL_TRAFFICCTL="${SCRIPT_DIR}/trafficctl.sh"

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

# 安装 bot listener（Telegram 命令监听）
if [ -n "$SCRIPT_DIR" ] && [ -f "$LOCAL_BOT" ]; then
  install -m 755 "$LOCAL_BOT" /opt/traffic-local/bot_listener.py
else
  download_file "${RAW_BASE}/bot_listener.py" "/opt/traffic-local/bot_listener.py"
  chmod 755 /opt/traffic-local/bot_listener.py
fi

# 安装 trafficctl（运维助手）
if [ -n "$SCRIPT_DIR" ] && [ -f "$LOCAL_TRAFFICCTL" ]; then
  install -m 755 "$LOCAL_TRAFFICCTL" /opt/traffic-local/trafficctl.sh
else
  download_file "${RAW_BASE}/trafficctl.sh" "/opt/traffic-local/trafficctl.sh"
  chmod 755 /opt/traffic-local/trafficctl.sh
fi
install -m 755 /opt/traffic-local/trafficctl.sh /usr/local/bin/trafficctl

# 节点清单模板（仅主控机需要）
if [ ! -f /opt/traffic-local/nodes.json ]; then
  if [ -n "$SCRIPT_DIR" ] && [ -f "$LOCAL_NODES_EXAMPLE" ]; then
    install -m 600 "$LOCAL_NODES_EXAMPLE" /opt/traffic-local/nodes.json
  else
    download_file "${RAW_BASE}/nodes.example.json" "/opt/traffic-local/nodes.json"
    chmod 600 /opt/traffic-local/nodes.json
  fi
fi

apply_nodes_payload_if_any

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

# 角色策略：master 负责命令监听，worker 仅定时上报
DEPLOY_ROLE="$(printf '%s' "$DEPLOY_ROLE" | tr '[:upper:]' '[:lower:]' | xargs)"
if [ "$DEPLOY_ROLE" = "master" ]; then
  ENABLE_BOT_LISTENER="true"
elif [ "$DEPLOY_ROLE" = "worker" ]; then
  ENABLE_BOT_LISTENER="false"
fi

if [ "$INIT" = "true" ]; then
  if [ -n "$SERVER_NAME" ] || [ -n "$LIMIT_GB" ] || [ -n "$CHAT_ID" ] || [ -n "$BOT_TOKEN" ]; then
    write_config_from_env
  else
    write_config_interactive
  fi

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

  if [ "$DEPLOY_ROLE" = "master" ]; then
    setup_bot_listener
  elif [ "$DEPLOY_ROLE" = "worker" ]; then
    echo "worker 角色默认不启用 Telegram 命令监听"
  else
    read -r -p "启用 Telegram 命令监听? [y/N]: " enable_listener || true
    case "${enable_listener:-n}" in
      y|Y|yes|YES)
        setup_bot_listener
        ;;
      *)
        echo "未启用 Telegram 命令监听"
        ;;
    esac
  fi

elif [ "$ENABLE_SYSTEMD_TIMER" = "true" ]; then
  setup_systemd_timer "$LOCAL_SERVICE" "$LOCAL_TIMER"
fi

if [ "$ENABLE_BOT_LISTENER" = "true" ]; then
  setup_bot_listener
else
  systemctl disable --now traffic-local-bot.service 2>/dev/null || true
fi

echo
echo "安装完成。"
echo "常用命令："
echo "  python3 /opt/traffic-local/report.py --dry-run"
echo "  python3 /opt/traffic-local/report.py --send"
echo "  python3 /opt/traffic-local/report.py --self-check"
echo "  trafficctl doctor"
echo
cat <<'CRON_HINT'
若你要手动使用 cron（23:55）：
  ( crontab -l 2>/dev/null | grep -v '/opt/traffic-local/report.py' ; \
    echo '55 23 * * * /usr/bin/python3 /opt/traffic-local/report.py --send >> /opt/traffic-local/run.log 2>&1' ) | crontab -
CRON_HINT
echo
echo "启用 Telegram 命令监听（可选）："
echo "  ENABLE_BOT_LISTENER=true bash <(curl -fsSL ${RAW_BASE}/install.sh)"

echo
cat <<'ENV_HINT'
环境变量一条命令安装（免交互）示例：
  SERVER_NAME="vps-01" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc"   SCHEDULE_MODE="cron" ENABLE_BOT_LISTENER="true" INIT=true   bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
ENV_HINT

cat <<'MASTER_CMD_HINT'
推荐部署方式：
  主控机（监听+远程查询）：
    DEPLOY_ROLE="master" INIT=true SCHEDULE_MODE="cron" SERVER_NAME="master" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)

  工作机（仅定时上报，不监听命令）：
    DEPLOY_ROLE="worker" INIT=true SCHEDULE_MODE="cron" SERVER_NAME="vps-01" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
MASTER_CMD_HINT

echo
echo "固定版本安装（可选）："
echo "  VERSION=v1.2.3 bash <(curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/install.sh)"
