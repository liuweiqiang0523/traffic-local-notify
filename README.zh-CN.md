# traffic-local-notify

[English](./README.md) | [简体中文](./README.zh-CN.md)

一个轻量、可复制的 VPS 月流量监控方案：

- `vnstat` 本地采集（每台服务器独立）
- Python 计算账期流量、历史归档
- Telegram Bot 推送（可多台共用）
- 可选 Telegram 命令监听（/traffic /selfcheck 等）

## 快速安装（root）

### 1) 一键安装（基础模式）
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

### 2) 一键安装 + 交互式初始化（推荐）
```bash
INIT=true bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

安装时会自动询问并可选启用 Telegram 命令监听。

### 3) 非交互直接启用 Telegram 命令监听
```bash
ENABLE_BOT_LISTENER=true bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

## Telegram 命令（v1.0.4）
启用 listener 后，在你配置的 chat_id 里可用：

- `/traffic`：查看当前流量（等价 `--dry-run`）
- `/traffic_send`：立即推送一条流量通知
- `/selfcheck`：执行自检
- `/help`：命令帮助

> 支持群话题（forum topic），会在当前 topic 回复。

## 一键自检（v1.0.3+）
```bash
python3 /opt/traffic-local/report.py --self-check
```

## 常用命令
```bash
traffic        # 仅本地查看（dry-run）
traffic-send   # 立即推送一次

python3 /opt/traffic-local/report.py --show-config
python3 /opt/traffic-local/report.py --dry-run
python3 /opt/traffic-local/report.py --send
python3 /opt/traffic-local/report.py --self-check

systemctl status traffic-local-bot.service
journalctl -u traffic-local-bot.service -n 50 --no-pager
```

## 许可证
MIT
