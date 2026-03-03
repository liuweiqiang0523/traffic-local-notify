# traffic-local-notify

[English](./README.md) | [简体中文](./README.zh-CN.md)

Lightweight per-server monthly traffic monitor with vnStat + Python + Telegram notifications.

## Features
- Per-server local collection via `vnstat`
- Monthly billing cycle (`billing_day` + `billing_hms`)
- Inbound / outbound / total traffic display
- Threshold alerts (default: 80/90/100)
- Manual query + force send
- One-shot self-check mode (`--self-check`)
- Optional `systemd timer` mode
- Optional Telegram command listener (`/traffic`, `/selfcheck`, ...)

## Quick Install (root)

### Basic
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

### Interactive setup
```bash
INIT=true bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

### Enable Telegram command listener directly
```bash
ENABLE_BOT_LISTENER=true bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

## Telegram Commands (v1.0.4)
- `/traffic`
- `/traffic_send`
- `/selfcheck`
- `/help`

## License
MIT
