# traffic-local-notify

[English](./README.md) | [简体中文](./README.zh-CN.md)

一个给 **小白也能用** 的 VPS 月流量通知工具：
- 本机通过 `vnstat` 统计流量
- 到点自动推送 Telegram
- 多机时：1 台主控 + N 台工作机

---

## 🚀 30 秒上手（推荐）

> 所有机器都先跑同一条命令：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/quick-install.sh) --defaults
```

然后按提示选角色：
- `master`：主控机（负责 Telegram 命令）
- `worker`：工作机（只负责本机上报）

安装时可直接填写 `ALLOWED_USER_IDS`，一次到位开启命令白名单。

---

## 🧩 你只需要理解这 2 件事

1. **主控机只要 1 台**
   - 跑 Telegram 命令监听
   - 可以远程查 worker 状态

2. **worker 可以很多台**
   - 每台只管自己流量
   - 可自动注册到 master

---

## 📱 Telegram 可用命令（在主控机）

- `/help`
- `/nodes`
- `/summary`（汇总 master + 所有节点）
- `/traffic`
- `/traffic <node>`
- `/selfcheck`
- `/selfcheck <node>`
- `/traffic_send`

---

## 🔐 强烈建议：开启白名单

编辑主控机配置：
```bash
nano /opt/traffic-local/config.json
```

加入：
```json
"allowed_user_ids": [241088406]
```

重启：
```bash
systemctl restart traffic-local-bot.service
```

---

## 📦 固定版本安装（生产建议）

避免后续 main 分支变动导致行为变化：

```bash
VERSION=v1.0.14 bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/install.sh)
```

---

## 🛠 常用排查

```bash
trafficctl doctor
python3 /opt/traffic-local/report.py --self-check
systemctl status traffic-local-bot.service --no-pager
journalctl -u traffic-local-bot.service -n 80 --no-pager
```

`trafficctl` 还支持：
- `trafficctl status`
- `trafficctl report`
- `trafficctl send`
- `trafficctl fix all`（自动修常见问题）
- `trafficctl restart bot`
- `trafficctl logs bot 100`
- `trafficctl why`（失败原因速查）

---

## 🧹 一键卸载

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/uninstall.sh)
```

---

## 📚 进阶文档

- 新手完整流程：[`docs/GETTING_STARTED.zh-CN.md`](./docs/GETTING_STARTED.zh-CN.md)
- 6 节点模板：`examples/nodes.6.example.json`
- 批量部署示例：`examples/deploy-6.sh`
- 节点配置模板：`nodes.example.json`

---

## 许可证

MIT
