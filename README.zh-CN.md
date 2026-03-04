# traffic-local-notify

[English](./README.md) | [简体中文](./README.zh-CN.md)

一个轻量、可复制的 VPS 月流量监控方案（多节点上报 + 单主控交互）。

## 推荐架构
- **主控机（master）**：负责 Telegram 命令监听与远程查询
- **工作机（worker）**：只做本机定时上报，不监听 Telegram 命令

这样可避免多个服务器抢同一个 bot `getUpdates`。

---

## 最省心：一条命令交互安装（主控/被控自动区分）
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/quick-install.sh)
```

极速默认模式（只问最少字段）：
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/quick-install.sh) --defaults
```

你只要按提示输入角色（master/worker）和基础参数即可。

## 一键脚本（你要的）

### A) 主控机一条命令
```bash
ROLE=master SERVER_NAME="master-hub" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
```

### B) 工作机一条命令
```bash
ROLE=worker SERVER_NAME="lax-01" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
```

> 默认 `SCHEDULE_MODE=cron`，如需改成 `systemd`，加：`SCHEDULE_MODE=systemd`。

---

## Telegram 命令（仅主控机）
- `/help`
- `/nodes`
- `/traffic`
- `/traffic <node>`
- `/selfcheck`
- `/selfcheck <node>`
- `/traffic_send`

## v1.0.8 自动回落
当 `/traffic <node>` 或 `/selfcheck <node>` 远程 SSH 失败时：
- 会返回失败原因（鉴权失败/超时/不可达等）
- 给出排查建议
- 自动附上主控机本地回落结果，避免“命令无响应”

---

## 主控机节点配置
编辑：
```bash
nano /opt/traffic-local/nodes.json
```

格式参考仓库里的 `nodes.example.json`。

---

## 卸载（已写进仓库）

### 一键卸载
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/uninstall.sh)
```

### 卸载会清理
- `/opt/traffic-local`
- `traffic-local-report.timer/service`
- `traffic-local-bot.service`
- 相关 crontab 项

---

## 常用排查
```bash
python3 /opt/traffic-local/report.py --self-check
systemctl status traffic-local-bot.service --no-pager
journalctl -u traffic-local-bot.service -n 80 --no-pager
```

## 许可证
MIT


## 6台服务器现成模板
- 节点模板：`examples/nodes.6.example.json`
- 批量部署示例：`examples/deploy-6.sh`

可直接按模板替换 IP/节点名后使用。


### 主控机真正一条命令（含 nodes.json）
你可把 nodes.json 先 base64 后直接传给脚本：
```bash
NODES_JSON_B64="<base64内容>" ROLE=master LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
```

生成 base64：
```bash
base64 -w0 nodes.json   # Debian/Ubuntu
# macOS: base64 -i nodes.json | tr -d "\n"
```

你也可以不传 `SERVER_NAME`，会自动用 `hostname-role` 命名。


## 全自动一条命令（v1.0.11）
目标：每台机器一条命令；worker 安装后自动注册到 master 的 nodes.json。

### 1) 先部署 master（只一次）
```bash
ROLE=master SERVER_NAME="master-hub" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
```

### 2) 每台 worker 一条命令（会自动注册到 master）
```bash
ROLE=worker SERVER_NAME="lax-01" LIMIT_GB="25600" CHAT_ID="-100xxxx" BOT_TOKEN="123:abc" \
MASTER_HOST="主控机IP" MASTER_USER="root" MASTER_KEY="/root/.ssh/id_ed25519" \
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
```

> 说明：
> - `MASTER_KEY` 是 worker 上用于 ssh 到 master 的私钥路径。
> - worker 会自动探测公网 IP 并写入 master 的 `/opt/traffic-local/nodes.json`。
> - 自动注册失败不会中断本机安装，会给出可手动补录的 JSON 条目。
