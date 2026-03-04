# traffic-local-notify

[English](./README.md) | [简体中文](./README.zh-CN.md)

Lightweight per-server monthly traffic monitor with vnStat + Python + Telegram notifications.

## Recommended Architecture
- **Master node**: Telegram command listener + remote query hub
- **Worker nodes**: scheduled local reporting only

This avoids multiple servers competing for one Telegram bot `getUpdates` stream.

## Easiest interactive one-liner
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/quick-install.sh)
```

Fast defaults mode:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/quick-install.sh) --defaults
```

This prompts role/params and runs setup automatically.

## One-command scripts (cluster)

### Master
```bash
ROLE=master SERVER_NAME="master-hub" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
```

### Worker
```bash
ROLE=worker SERVER_NAME="lax-01" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
```

## Telegram Commands (master)
- `/help`
- `/nodes`
- `/traffic`
- `/traffic <node>`
- `/selfcheck`
- `/selfcheck <node>`
- `/traffic_send`

## v1.0.8 fallback behavior
If remote SSH query fails, bot returns:
- classified failure reason
- troubleshooting hints
- fallback local result from master

## Uninstall
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/uninstall.sh)
```

Removes:
- `/opt/traffic-local`
- report timer/service
- bot listener service
- related cron entries

## License
MIT


## 6-node templates
- Node inventory template: `examples/nodes.6.example.json`
- Deployment helper sample: `examples/deploy-6.sh`


## Master one-liner with preloaded nodes.json
```bash
NODES_JSON_B64="<base64>" ROLE=master LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
```


## Fully automated one-command mode (v1.0.11)
Workers can auto-register themselves to master `nodes.json`.

### Master (once)
```bash
ROLE=master SERVER_NAME="master-hub" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
```

### Worker (per node)
```bash
ROLE=worker SERVER_NAME="lax-01" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
MASTER_HOST="<master-ip>" MASTER_USER="root" MASTER_KEY="/root/.ssh/id_ed25519" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
```
