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
BILLING_DAY="${BILLING_DAY:-27}"
BILLING_HMS="${BILLING_HMS:-00:02:06}"
CHAT_ID="${CHAT_ID:-}"
BOT_TOKEN="${BOT_TOKEN:-}"
DEPLOY_ROLE="${DEPLOY_ROLE:-worker}" # master|worker
ALLOWED_USER_IDS="${ALLOWED_USER_IDS:-}" # comma-separated telegram user ids

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

  local allowed_json=""
  if [ -n "$ALLOWED_USER_IDS" ]; then
    allowed_json="$(printf '%s' "$ALLOWED_USER_IDS" | tr ',' '\n' | sed '/^$/d' | sed 's/[^0-9]//g' | awk 'NF{printf "%s%s", sep, $1; sep=","}')"
  fi

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
  allowed_json=""
  if [ -n "$allow_ids" ]; then
    allowed_json="$(printf "%s" "$allow_ids" | tr "," "\n" | sed '/^$/d' | sed 's/[^0-9]//g' | awk 'NF{printf "%s%s", sep, $1; sep=","}')"
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
  "alert_levels": [80, 90, 100],
  "allowed_user_ids": [${allowed_json}]
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
echo "  VERSION=v1.2.0 bash <(curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/install.sh)"
