# traffic-local-notify

[English](./README.md) | [简体中文](./README.zh-CN.md)

Lightweight per-server monthly traffic monitor with vnStat + Python + Telegram notifications.

## Recommended Architecture (for 5~6 servers)
- **Master node**: command listener + remote query hub
- **Worker nodes**: scheduled local reporting only

This avoids multiple servers competing for the same Telegram `getUpdates` stream.

## One-line Deploy (v1.0.7)

### Master
```bash
DEPLOY_ROLE="master" INIT=true SCHEDULE_MODE="cron" \
SERVER_NAME="master-hub" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

### Worker
```bash
DEPLOY_ROLE="worker" INIT=true SCHEDULE_MODE="cron" \
SERVER_NAME="lax-01" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

## Telegram Commands (master only)
- `/help`
- `/nodes`
- `/traffic`
- `/traffic <node>`
- `/selfcheck`
- `/selfcheck <node>`
- `/traffic_send`

## Remote Node List (master)
Configure `/opt/traffic-local/nodes.json` (generated from `nodes.example.json`) and ensure SSH key-based access from master to workers.

## License
MIT
