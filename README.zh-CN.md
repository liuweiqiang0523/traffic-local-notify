# traffic-local-notify

[English](./README.md) | [简体中文](./README.zh-CN.md)

一个轻量、可复制的 VPS 月流量监控方案：

- `vnstat` 本地采集（每台服务器独立）
- Python 计算账期流量、历史归档
- Telegram Bot 推送（可多台共用）

## 快速安装（root）

### 1) 一键安装（基础模式）
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

### 2) 一键安装 + 交互式初始化（推荐，v1.0.2）
```bash
INIT=true bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

安装时会直接询问：
- 服务器名称
- 网卡（支持 `auto`）
- 月限额
- 账期日/账期时间
- Telegram chat_id
- Telegram bot token

并自动：
- 写配置
- 测试推送一次
- 让你选择 cron / systemd / none 定时模式

## 定时方案

### 方案 A：cron（每天 23:55）
```bash
( crontab -l 2>/dev/null | grep -v '/opt/traffic-local/report.py' ; \
  echo '55 23 * * * /usr/bin/python3 /opt/traffic-local/report.py --send >> /opt/traffic-local/run.log 2>&1' ) | crontab -
```

### 方案 B：systemd timer（推荐更稳）
```bash
ENABLE_SYSTEMD_TIMER=true bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
systemctl status traffic-local-report.timer
systemctl list-timers | grep traffic-local-report
```

## 常用命令
```bash
traffic        # 仅本地查看（dry-run）
traffic-send   # 立即推送一次

python3 /opt/traffic-local/report.py --show-config
python3 /opt/traffic-local/report.py --dry-run
python3 /opt/traffic-local/report.py --send

tail -n 50 /opt/traffic-local/run.log
cat /opt/traffic-local/state.json
```

## 新特性（v1.0.2）
- 交互式初始化：`INIT=true`
- 安装后自动测试推送
- 安装时可选定时方式（cron/systemd/none）

## 新特性（v1.0.1）
- 支持 `interface: auto` 自动网卡检测
- 错误提示更详细（vnstat/JSON/Telegram）
- 新增 systemd timer 模板

## 配置字段说明
见：`config.template.json`

## 许可证
MIT
