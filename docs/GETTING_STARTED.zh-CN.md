# 新手教程（一步一步）

> 目标：10 分钟内完成 1 主 1 从部署。

## 0. 准备
- 你要有一个 Telegram bot token
- 你要知道目标群 chat_id（如 `-100xxxx`）

## 1. 在主控机执行
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/quick-install.sh) --defaults
```
按提示选 `master`。

## 2. 在工作机执行
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/quick-install.sh) --defaults
```
按提示选 `worker`，并填写 `MASTER_HOST`（主控 IP）。

## 3. 在主控机加白名单（强烈建议）
编辑配置：
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

## 4. 在 Telegram 测试
- `/nodes`
- `/summary`
- `/traffic <worker名>`

## 5. 看是否安装成功
主控机执行：
```bash
python3 /opt/traffic-local/report.py --self-check
systemctl status traffic-local-bot.service --no-pager
```

## 常见问题

### Q1: `/traffic <node>` 报 SSH 鉴权失败
把主控公钥加入 worker 的 `~/.ssh/authorized_keys`。

### Q2: 看不到定时发送
检查：
```bash
crontab -l
# 或
systemctl status traffic-local-report.timer --no-pager
```

### Q3: 我只想本机，不要集群
也可以直接装成 worker，用 `/traffic` 看本机。


## 一键修复常见问题
```bash
trafficctl fix all
trafficctl doctor
```


## 失败了先看这个
```bash
trafficctl why
```
