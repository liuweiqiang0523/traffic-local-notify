#!/usr/bin/env python3
import os
import json
import argparse
import datetime
import subprocess
import urllib.request
import urllib.parse

CFG = "/opt/traffic-local/config.json"
STA = "/opt/traffic-local/state.json"

def load_json(path, default):
if not os.path.exists(path):
return default
with open(path, "r", encoding="utf-8") as f:
return json.load(f)

def save_json(path, data):
with open(path, "w", encoding="utf-8") as f:
json.dump(data, f, ensure_ascii=False, indent=2)

def tb(v): return v / (1024 ** 4)
def gb(v): return v / (1024 ** 3)

def fmt(ts):
return datetime.datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")

def cycle_start(now, day, hms):
h, m, s = map(int, hms.split(":"))
cur = datetime.datetime(now.year, now.month, day, h, m, s, tzinfo=now.tzinfo)
if now >= cur:
return cur
y, mo = now.year, now.month - 1
if mo == 0:
y, mo = y - 1, 12
return datetime.datetime(y, mo, day, h, m, s, tzinfo=now.tzinfo)

def tg_send(token, chat_id, text):
url = f"https://api.telegram.org/bot{token}/sendMessage"
data = urllib.parse.urlencode({"chat_id": chat_id, "text": text}).encode()
req = urllib.request.Request(url, data=data, method="POST")
urllib.request.urlopen(req, timeout=15).read()

def main():
ap = argparse.ArgumentParser()
ap.add_argument("--send", action="store_true", help="强制推送 Telegram")
ap.add_argument("--dry-run", action="store_true", help="只输出，不推送")
args = ap.parse_args()

cfg = load_json(CFG, {})
if not cfg:
raise SystemExit("缺少配置文件 /opt/traffic-local/config.json")

iface = cfg.get("interface", "eth0")

raw = subprocess.check_output(["vnstat", "--json"], text=True)
j = json.loads(raw)

rx = tx = None
for itf in j.get("interfaces", []):
if itf.get("name") == iface:
total = itf.get("traffic", {}).get("total", {})
rx = total.get("rx")
tx = total.get("tx")
break

if rx is None or tx is None:
raise SystemExit(f"找不到网卡 {iface} 的 vnstat total 数据")

rx = int(rx)
tx = int(tx)

now = datetime.datetime.now().astimezone()
cstart = int(cycle_start(now, int(cfg["billing_day"]), cfg["billing_hms"]).timestamp())

st = load_json(STA, {
"cycle_start_ts": cstart,
"start_rx": rx,
"start_tx": tx,
"history": [],
"alerted": []
})

if st["cycle_start_ts"] != cstart:
prx = max(0, rx - st["start_rx"])
ptx = max(0, tx - st["start_tx"])
ps = prx + ptx
st["history"].append({
"cycle_start_ts": st["cycle_start_ts"],
"in_tb": round(tb(prx), 2),
"out_tb": round(tb(ptx), 2),
"sum_tb": round(tb(ps), 2),
"limit_gb": cfg["limit_gb"]
})
st["history"] = st["history"][-12:]
st["cycle_start_ts"] = cstart
st["start_rx"] = rx
st["start_tx"] = tx
st["alerted"] = []

cur_rx = max(0, rx - st["start_rx"])
cur_tx = max(0, tx - st["start_tx"])
cur_sum = cur_rx + cur_tx

used_gb = gb(cur_sum)
limit_gb = float(cfg["limit_gb"])
pct = (used_gb / limit_gb * 100) if limit_gb > 0 else 0

msg = (
f"🖥️ 服务器：{cfg['server_name']}\n"
f"🕐 周期起始：{fmt(st['cycle_start_ts'])}\n"
f"⬇️ 入站流量：{tb(cur_rx):>8.2f} TB\n"
f"⬆️ 出站流量：{tb(cur_tx):>8.2f} TB\n"
f"📈 已用流量：{tb(cur_sum):>8.2f} TB\n"
f"📊 流量限额：{limit_gb:>8,.0f} GB（{pct:>5.1f}%）\n"
f"📋 历史流量：\n"
)

if st["history"]:for h in st["history"][-3:][::-1]:
msg += (
f" • {fmt(h['cycle_start_ts'])} "
f"总用量 {h['sum_tb']:>6.2f} TB / 限额 {h['limit_gb']:>7,.0f} GB\n"
)
else:
msg += " • 暂无历史记录\n"

alert_levels = cfg.get("alert_levels", [80, 90, 100])
need_alert = False
for lv in alert_levels:
key = str(int(lv))
if pct >= float(lv) and key not in st.get("alerted", []):
st.setdefault("alerted", []).append(key)
need_alert = True

save_json(STA, st)

print(msg.strip())
print("OK")

if args.dry_run:
return

should_send = args.send or bool(cfg.get("send_always", False)) or need_alert
if should_send:
token_path = cfg["telegram_bot_token_file"]
if not os.path.exists(token_path):
raise SystemExit(f"缺少 token 文件：{token_path}")
bot_token = open(token_path, "r", encoding="utf-8").read().strip()
tg_send(bot_token, cfg["telegram_chat_id"], msg[:3900])

if __name__ == "__main__":
main()
