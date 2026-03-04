# traffic-local-notify

[English](./README.md) | [简体中文](./README.zh-CN.md)

A beginner-friendly VPS monthly traffic notifier:
- uses `vnstat` on each machine
- sends Telegram notifications on schedule
- supports multi-node layout: 1 master + N workers

---

## 🚀 30-second start (recommended)

Run this on any server (it asks LIMIT_GB per server; no fixed 25TB default):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/quick-install.sh) --defaults
```

Then choose role when prompted:
- `master`: command listener + remote queries
- `worker`: local reporting only

You can also input `ALLOWED_USER_IDS` during install to enable command allowlist immediately.

Billing cycle now defaults to the current install time (no fixed 27th 00:02:06).

---

## What to remember

1. Only **one master** is needed.
2. Workers can scale out; each reports its own traffic.

---

## Telegram commands (master)

- `/help`
- `/nodes`
- `/summary` (master + all workers)
- `/traffic`
- `/traffic <node>`
- `/selfcheck`
- `/selfcheck <node>`
- `/traffic_send`

---

## Security: command allowlist (recommended)

Edit config:
```bash
nano /opt/traffic-local/config.json
```

Add:
```json
"allowed_user_ids": [241088406]
```

Restart listener:
```bash
systemctl restart traffic-local-bot.service
```

---

## Pin installer version (recommended for production)

```bash
VERSION=v1.0.14 bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

---

## Troubleshooting

```bash
trafficctl doctor
python3 /opt/traffic-local/report.py --self-check
systemctl status traffic-local-bot.service --no-pager
journalctl -u traffic-local-bot.service -n 80 --no-pager
```

`trafficctl` also supports:
- `trafficctl status`
- `trafficctl report`
- `trafficctl send`
- `trafficctl fix all` (auto-fix common issues)
- `trafficctl restart bot`
- `trafficctl logs bot 100`
- `trafficctl why` (quick failure lookup)
- `trafficctl rebase now` (reset cycle start to now)

---

## Uninstall

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/uninstall.sh)
```

---

## Advanced docs

- Beginner guide: [`docs/GETTING_STARTED.md`](./docs/GETTING_STARTED.md)
- 6-node template: `examples/nodes.6.example.json`
- batch deploy sample: `examples/deploy-6.sh`
- nodes template: `nodes.example.json`

---

## License

MIT


## Billing (billing_day + billing_hms)
Set billing cycle explicitly per server:

```bash
trafficctl set-billing 1 00:00:00
trafficctl show-billing
```

If you want immediate cycle baseline reset:
```bash
trafficctl rebase now
```


### Per-server traffic quota
```bash
trafficctl set-limit 12288
trafficctl show-limit
```


### billing_day supports 1~31
- Supports 29/30/31
- On short months, it falls back to month-end automatically (e.g. day 31 -> Feb 28/29).
