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

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || return 1
}

download_file() {
  local url="$1"
  local out="$2"
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
  echo "已创建 /opt/traffic-local/tg_bot_token.txt（请填 bot token）"
fi

if ! grep -q "alias traffic='python3 /opt/traffic-local/report.py --dry-run'" /root/.bashrc 2>/dev/null; then
  cat >> /root/.bashrc <<'E2'
alias traffic='python3 /opt/traffic-local/report.py --dry-run'
alias traffic-send='python3 /opt/traffic-local/report.py --send'
E2
fi

echo
echo "安装完成，下一步："
echo "1) 编辑配置: nano /opt/traffic-local/config.json"
echo "2) 写入Token: nano /opt/traffic-local/tg_bot_token.txt"
echo "3) 测试推送: python3 /opt/traffic-local/report.py --send"
echo "4) 配cron(23:55):"
echo "   ( crontab -l 2>/dev/null | grep -v '/opt/traffic-local/report.py' ; \\\" 
echo "     echo '55 23 * * * /usr/bin/python3 /opt/traffic-local/report.py --send >> /opt/traffic-local/run.log 2>&1' ) | crontab -"
