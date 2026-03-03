# traffic-local-notify

[English](./README.md) | [简体中文](./README.zh-CN.md)

Lightweight per-server monthly traffic monitor with vnStat + Python + Telegram notifications.

## Features
- Per-server local collection via `vnstat`
- Monthly billing cycle (`billing_day` + `billing_hms`)
- Inbound / outbound / total traffic display
- Threshold alerts (default: 80/90/100)
- Manual query + force send
- Better error messages for common failures
- Auto interface support (`"interface": "auto"`)
- Optional `systemd timer` mode
- Interactive init mode (`INIT=true`)
- One-shot self-check mode (`--self-check`)

## Quick Install (root)

### Basic install
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

### Interactive setup (recommended)
```bash
INIT=true bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

## Self Check
```bash
python3 /opt/traffic-local/report.py --self-check
```

## Scheduling

### Option A: cron (23:55 daily)
```bash
( crontab -l 2>/dev/null | grep -v '/opt/traffic-local/report.py' ; \
  echo '55 23 * * * /usr/bin/python3 /opt/traffic-local/report.py --send >> /opt/traffic-local/run.log 2>&1' ) | crontab -
```

### Option B: systemd timer
```bash
ENABLE_SYSTEMD_TIMER=true bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
systemctl status traffic-local-report.timer
systemctl list-timers | grep traffic-local-report
```

## License
MIT
