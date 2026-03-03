# traffic-local-notify

[English](./README.md) | [简体中文](./README.zh-CN.md)

一个轻量、可复制的 VPS 月流量监控方案：

- `vnstat` 本地采集（每台服务器独立）
- Python 计算账期流量、历史归档
- Telegram Bot 推送（可多台共用）

## 快速安装（root）
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

安装后：
```bash
nano /opt/traffic-local/config.json
nano /opt/traffic-local/tg_bot_token.txt
python3 /opt/traffic-local/report.py --send
```

## 每天 23:55 定时推送
```bash
( crontab -l 2>/dev/null | grep -v '/opt/traffic-local/report.py' ; \
  echo '55 23 * * * /usr/bin/python3 /opt/traffic-local/report.py --send >> /opt/traffic-local/run.log 2>&1' ) | crontab -
```

## 常用命令
```bash
traffic        # 仅本地查看（dry-run）
traffic-send   # 立即推送一次

tail -n 50 /opt/traffic-local/run.log
cat /opt/traffic-local/state.json
```

## 配置字段说明
见：`config.template.json`

## 许可证
MIT
