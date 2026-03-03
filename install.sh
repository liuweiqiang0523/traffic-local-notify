#!/usr/bin/env bash
set -euo pipefail

echo "== traffic-local-notify installer =="

if [ "$(id -u)" -ne 0 ]; then
echo "请用 root 运行"
exit 1
fi

apt-get update
apt-get install -y python3 vnstat
systemctl enable --now vnstat

mkdir -p /opt/traffic-local
chmod 700 /opt/traffic-local

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

install -m 755 "$SCRIPT_DIR/report.py" /opt/traffic-local/report.py

if [ ! -f /opt/traffic-local/config.json ]; then
install -m 600 "$SCRIPT_DIR/config.template.json" /opt/traffic-local/config.json
echo "已生成 /opt/traffic-local/config.json（请编辑）"
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
echo "下一步："
echo "1) 编辑配置: nano /opt/traffic-local/config.json"
echo "2) 写入Token: nano /opt/traffic-local/tg_bot_token.txt"
echo "3) 测试推送: python3 /opt/traffic-local/report.py --send"
echo "4) 配cron(23:55):"
echo " ( crontab -l 2>/dev/null | grep -v '/opt/traffic-local/report.py' ; \\"
echo " echo '55 23 * * * /usr/bin/python3 /opt/traffic-local/report.py --send >> /opt/traffic-local/run.log 2>&1' ) | crontab -"
