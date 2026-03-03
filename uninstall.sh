#!/usr/bin/env bash
set -euo pipefail

crontab -l 2>/dev/null | grep -v '/opt/traffic-local/report.py' | crontab - || true

systemctl disable --now traffic-local-report.timer 2>/dev/null || true
systemctl disable --now traffic-local-bot.service 2>/dev/null || true
rm -f /etc/systemd/system/traffic-local-report.service /etc/systemd/system/traffic-local-report.timer
rm -f /etc/systemd/system/traffic-local-bot.service
systemctl daemon-reload || true

rm -rf /opt/traffic-local

echo "已卸载 traffic-local-notify（含 cron + systemd timer + bot listener）。"
