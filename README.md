# traffic-local-notify

轻量、可复制的 VPS 月流量监控方案：

- 基于 `vnstat` 本地采集（每台服务器独立）
- 基于 `Python` 计算账期流量与历史归档
- 基于 Telegram Bot 推送（可共用同一个 Bot）

适合场景：多台 VPS、不同月结时间、希望低依赖、可快速批量落地。

---

## 这是什么

`traffic-local-notify` 是一个“每台服务器自给自足”的流量通知脚本包：

- 不依赖中心化面板 API
- 不要求额外数据库
- 配置简单，迁移快
- 支持一行安装

---

## 功能

- 月账期自定义：`billing_day + billing_hms`
- 入站/出站/总量分别展示
- 流量阈值告警：默认 `80/90/100`
- 历史账期保留（最近 12 条）
- 手动查询与手动强推

---

## 快速开始（推荐）

在新服务器（root）执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

安装后按提示完成：

```bash
nano /opt/traffic-local/config.json
nano /opt/traffic-local/tg_bot_token.txt
python3 /opt/traffic-local/report.py --send
```

添加每天 23:55 定时推送：

```bash
( crontab -l 2>/dev/null | grep -v '/opt/traffic-local/report.py' ; \
  echo '55 23 * * * /usr/bin/python3 /opt/traffic-local/report.py --send >> /opt/traffic-local/run.log 2>&1' ) | crontab -
```

---

## 配置说明（`/opt/traffic-local/config.json`）

```json
{
  "server_name": "my-vps-01",
  "interface": "eth0",
  "limit_gb": 25600,
  "billing_day": 27,
  "billing_hms": "00:02:06",
  "telegram_bot_token_file": "/opt/traffic-local/tg_bot_token.txt",
  "telegram_chat_id": "-100xxxxxxxxxx",
  "send_always": false,
  "alert_levels": [80, 90, 100]
}
```

字段解释：

- `server_name`：服务器名称（建议唯一）
- `interface`：统计网卡名（如 `eth0`）
- `limit_gb`：月流量上限（GB）
- `billing_day`：每月结算日（1-28 更稳妥）
- `billing_hms`：结算时间（`HH:MM:SS`）
- `telegram_bot_token_file`：Token 文件路径
- `telegram_chat_id`：群/频道 ID
- `send_always`：是否每次执行都推送（建议 `false`）
- `alert_levels`：阈值列表，超过后告警并记忆

---

## 常用命令

```bash
traffic        # 本地查看（dry-run，不推送）
traffic-send   # 立即推送一次

python3 /opt/traffic-local/report.py --dry-run
python3 /opt/traffic-local/report.py --send

tail -n 50 /opt/traffic-local/run.log
cat /opt/traffic-local/state.json
```

---

## 仓库文件说明

- `install.sh`：安装器（支持 git clone / curl 单文件两种模式）
- `report.py`：核心统计与通知脚本
- `config.template.json`：配置模板
- `uninstall.sh`：卸载脚本

---

## 卸载

```bash
bash /path/to/uninstall.sh
```

会删除：

- `/opt/traffic-local`
- 与 `report.py` 相关的 crontab 项

---

## 安全建议

- 不要把 Bot Token 写入仓库
- `tg_bot_token.txt` 权限保持 `600`
- 不要在群聊公开服务器凭据

---

## About（GitHub 仓库简介建议）

> Lightweight per-server monthly traffic monitor with vnStat + Python + Telegram notifications.
