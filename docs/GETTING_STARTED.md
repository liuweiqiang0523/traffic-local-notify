# Getting Started (Beginner)

Goal: finish a 1-master + 1-worker setup in ~10 minutes.

## 0) Prepare
- Telegram bot token
- target chat_id (e.g. `-100xxxx`)

## 1) On master
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/quick-install.sh) --defaults
```
Choose `master`.

## 2) On worker
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/quick-install.sh) --defaults
```
Choose `worker`, set `MASTER_HOST`.

## 3) Enable command allowlist (recommended)
Edit:
```bash
nano /opt/traffic-local/config.json
```
Add:
```json
"allowed_user_ids": [241088406]
```
Restart:
```bash
systemctl restart traffic-local-bot.service
```

## 4) Telegram checks
- `/nodes`
- `/summary`
- `/traffic <worker-name>`

## 5) Verify service status
On master:
```bash
python3 /opt/traffic-local/report.py --self-check
systemctl status traffic-local-bot.service --no-pager
```

## FAQ

### SSH auth failed on `/traffic <node>`
Add master public key into worker `~/.ssh/authorized_keys`.

### No scheduled notifications
Check:
```bash
crontab -l
# or
systemctl status traffic-local-report.timer --no-pager
```

### Single node only
Install as worker role and just use local `/traffic`.


## Auto-fix common issues
```bash
trafficctl fix all
trafficctl doctor
```


## Quick failure lookup
```bash
trafficctl why
```
