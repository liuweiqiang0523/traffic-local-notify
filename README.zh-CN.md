# traffic-local-notify

[English](./README.md) | [简体中文](./README.zh-CN.md)

一个轻量、可复制的 VPS 月流量监控方案（多节点上报 + 单主控交互）。

## 推荐架构（5~6 台服务器最佳）
- **主控机（master）**：负责 Telegram 命令监听与远程查询
- **工作机（worker）**：只做本机定时上报，不监听 Telegram 命令

这样可以避免多个服务器抢同一个 bot `getUpdates`。

---

## 一条命令部署（v1.0.7）

### 主控机（监听 + 远程查询）
```bash
DEPLOY_ROLE="master" INIT=true SCHEDULE_MODE="cron" \
SERVER_NAME="master-hub" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

### 工作机（仅上报，不监听）
```bash
DEPLOY_ROLE="worker" INIT=true SCHEDULE_MODE="cron" \
SERVER_NAME="lax-01" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

---

## Telegram 命令（仅主控机启用）
- `/help`
- `/nodes`（列出可查询节点）
- `/traffic`（主控机本地）
- `/traffic <node>`（查询指定节点）
- `/selfcheck`（主控机本地）
- `/selfcheck <node>`（指定节点）
- `/traffic_send`（主控机立即推送）

---

## 配置主控机远程节点列表
主控机会自动生成：
- `/opt/traffic-local/nodes.json`（初始模板）

可参考 `nodes.example.json` 填写，示例：
```json
[
  {"name":"lax-01","host":"1.2.3.4","port":22,"user":"root","key":"/root/.ssh/id_ed25519"},
  {"name":"hkg-01","host":"5.6.7.8","port":22,"user":"root","key":"/root/.ssh/id_ed25519"}
]
```

> 主控机需能 SSH 免密到各 worker。

---

## 自检
```bash
python3 /opt/traffic-local/report.py --self-check
```

## 常用命令
```bash
python3 /opt/traffic-local/report.py --dry-run
python3 /opt/traffic-local/report.py --send
python3 /opt/traffic-local/report.py --self-check

systemctl status traffic-local-bot.service
journalctl -u traffic-local-bot.service -n 80 --no-pager
```

## 许可证
MIT
