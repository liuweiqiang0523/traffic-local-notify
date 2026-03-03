#!/usr/bin/env bash
set -euo pipefail
crontab -l 2>/dev/null | grep -v '/opt/traffic-local/report.py' | crontab - || true
rm -rf /opt/traffic-local
echo "已卸载 traffic-local-notify。"
